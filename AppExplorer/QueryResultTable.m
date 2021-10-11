// Copyright (c) 2008,2012,2014,2018,2020 Simon Fell
//
// Permission is hereby granted, free of charge, to any person obtaining a 
// copy of this software and associated documentation files (the "Software"), 
// to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense, 
// and/or sell copies of the Software, and to permit persons to whom the 
// Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included 
// in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS 
// OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN 
// THE SOFTWARE.
//

#import "QueryResultTable.h"
#import <ZKSforce/ZKSforce.h>
#import "EditableQueryResultWrapper.h"
#import "SearchQueryResult.h"
#import "QueryColumns.h"
#import "SObjectSortDescriptor.h"

@interface WidthStats : NSObject
@property (assign) NSInteger count;
@property (assign) NSInteger max;
@property (assign) NSInteger percentile80;
@property (assign) NSInteger headerWidth;
@property (retain) NSTableColumn *column;
@end

@implementation WidthStats
@end

@interface WidthStatsBuilder : NSObject {
    NSMutableArray<NSNumber*>*  vals;
    NSInteger                   minToConsider;
    NSInteger                   minCount;
    NSInteger                   headerWidth;
}
-(instancetype)initWithMin:(NSInteger)min;
// the first item in the array is expected to be the column title
-(void)addStrings:(NSArray<NSString*>*)strings font:(NSFont*)f;

-(WidthStats*)resultsWithOffset:(NSInteger)pad;
@property (retain) NSTableColumn *column;
@end

@implementation WidthStatsBuilder

-(instancetype)initWithMin:(NSInteger)min {
    self = [super init];
    minToConsider = min;
    vals = [NSMutableArray array];
    return self;
}

-(void)addStrings:(NSArray<NSString *> *)strings font:(NSFont *)font {
    // see https://stackoverflow.com/questions/30537811/performance-of-measuring-text-width-in-appkit
    NSString *bigString = [strings componentsJoinedByString:@"\n"];
    NSAttributedString *richText = [[NSAttributedString alloc]
                                        initWithString:bigString
                                        attributes:@{ NSFontAttributeName: font }];
    CGPathRef path = CGPathCreateWithRect(CGRectMake(0, 0, CGFLOAT_MAX, CGFLOAT_MAX), NULL);
    CTFramesetterRef setter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)richText);
    CTFrameRef frame = CTFramesetterCreateFrame(setter, CFRangeMake(0, bigString.length), path, NULL);
    NSArray *lines = (__bridge NSArray *)CTFrameGetLines(frame);
    [lines enumerateObjectsUsingBlock:^(id  _Nonnull item, NSUInteger idx, BOOL * _Nonnull stop) {
        CTLineRef line = (__bridge CTLineRef)item;
        CGFloat w = ceil(CTLineGetTypographicBounds(line, NULL, NULL, NULL));
        if (idx == 0) {
            headerWidth = w;
        } else if (w <= minToConsider) {
            ++minCount;
        } else {
            [vals addObject:@(w)];
        }
    }];
    CFRelease(frame);
    CFRelease(setter);
    CFRelease(path);
}

-(WidthStats*)resultsWithOffset:(NSInteger)pad {
    [vals sortUsingSelector:@selector(compare:)];
    WidthStats *r = [[WidthStats alloc] init];
    r.max = pad + (vals.count == 0 ? minToConsider : vals.lastObject.integerValue);
    r.count = vals.count + minCount;
    NSInteger p80Idx = 0.8 * r.count;
    r.percentile80 = pad + (p80Idx <= minCount ? minToConsider : vals[p80Idx-minCount].integerValue);
    r.headerWidth = pad + headerWidth;
    r.column = self.column;
    return r;
}

@end

@interface QueryResultTable ()
- (NSArray *)createTableColumns:(ZKQueryResult *)qr;
@end


@implementation QueryResultTable

@synthesize table, delegate;

- (instancetype)initForTableView:(NSTableView *)view {
    self = [super init];
    table = view;
    return self;
}

- (void)dealloc {
    [wrapper removeObserver:self forKeyPath:@"hasCheckedRows"];
}

- (ZKQueryResult *)queryResult {
    return wrapper.queryResult;
}

- (EditableQueryResultWrapper *)wrapper {
    return wrapper;
}

-(BOOL)hasCheckedRows {
    return [wrapper hasCheckedRows];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == wrapper) {
        [self willChangeValueForKey:@"hasCheckedRows"];
        [self didChangeValueForKey:@"hasCheckedRows"];
    }
}

- (void)updateTable {
    [wrapper setDelegate:delegate];
    table.delegate = wrapper;
    table.dataSource = wrapper;
    [self showHideErrorColumn];
}

-(void)showHideErrorColumn {
    NSTableColumn *ec = [table tableColumnWithIdentifier:ERROR_COLUMN_IDENTIFIER];
    BOOL hasErrors = wrapper.hasErrors;
    ec.hidden = !hasErrors;
    [table reloadData];
}

- (void)setQueryResult:(ZKQueryResult *)qr {
    if (qr == wrapper.queryResult) return;
    [wrapper removeObserver:self forKeyPath:@"hasCheckedRows"];
    [self willChangeValueForKey:@"hasCheckedRows"];
    wrapper = [[EditableQueryResultWrapper alloc] initWithQueryResult:qr];
    [self didChangeValueForKey:@"hasCheckedRows"];
    [wrapper addObserver:self forKeyPath:@"hasCheckedRows" options:0 context:nil];
//    int idxToDelete=0;
//    while (table.numberOfColumns > 2) {
//        NSString *colId = table.tableColumns[idxToDelete].identifier;
//        if ([colId isEqualToString:DELETE_COLUMN_IDENTIFIER] || [colId isEqualToString:ERROR_COLUMN_IDENTIFIER]) {
//            idxToDelete++;
//            continue;
//        }
//        [table removeTableColumn:table.tableColumns[idxToDelete]];
//    }
    [table tableColumnWithIdentifier:ERROR_COLUMN_IDENTIFIER].hidden = TRUE;
    NSArray *cols = [self createTableColumns:qr];
    [wrapper setEditable:[cols containsObject:@"Id"]];
    [self updateTable];
}

-(void)replaceQueryResult:(ZKQueryResult *)qr {
    [wrapper setQueryResult:qr];
    [self showHideErrorColumn];
}

- (void)removeRowsWithIds:(NSSet<NSString*> *)recordIds {
    [wrapper removeRowsWithIds:recordIds];
    [self updateTable];
}

- (NSTableColumn *)createTableColumnWithIdentifier:(NSString *)identifier label:(NSString *)label {
    NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:identifier];
    col.headerCell.stringValue = label;
    col.editable = YES;
    col.minWidth = 40;
    col.resizingMask = NSTableColumnUserResizingMask | NSTableColumnAutoresizingMask;
    if ([identifier hasSuffix:@"Id"]) {
        col.width = 165;
    }
    col.sortDescriptorPrototype = [[SObjectSortDescriptor alloc] initWithKey:identifier ascending:YES describer:self.describer];
    return col;
}

- (NSArray *)createTableColumns:(ZKQueryResult *)qr {
    QueryColumns *qcols = [[QueryColumns alloc] initWithResult:qr];
    if (qcols.isSearchResult) {
        [table addTableColumn:[self createTableColumnWithIdentifier:TYPE_COLUMN_IDENTIFIER label:@"Type"]];
    }
    NSMutableSet<NSString*> *colIds = [[NSMutableSet alloc] initWithCapacity:qcols.names.count+2];
    NSMutableArray<NSTableColumn*>* newCols = [NSMutableArray array];
    NSInteger idx = 2;
    for (NSString *colName in qcols.names) {
        NSInteger existingIdx = [table columnWithIdentifier:colName];
        if (existingIdx == -1) {
            NSTableColumn *col = [self createTableColumnWithIdentifier:colName label:colName];
            [table addTableColumn:col];
            existingIdx = table.numberOfColumns-1;
        }
        if (existingIdx != idx) {
            [table moveColumn:existingIdx toColumn:idx];
        }
        [newCols addObject:table.tableColumns[idx]];
        idx++;
        [colIds addObject:colName];
    }
    [colIds addObject:DELETE_COLUMN_IDENTIFIER];
    [colIds addObject:ERROR_COLUMN_IDENTIFIER];
    idx = 0;
    while (idx < table.tableColumns.count) {
        NSString *colId = table.tableColumns[idx].identifier;
        if ([colIds containsObject:colId]) {
            idx++;
            continue;
        }
        [table removeTableColumn:table.tableColumns[idx]];
    }
    // Resize any new columns
    if (newCols.count > 0) {
        NSDate *start = [NSDate date];
        CGFloat totalColWidth = 0;
        CGFloat colSpacing = table.intercellSpacing.width*2;
        
        for (NSTableColumn *c in table.tableColumns) {
            if (!c.isHidden) {
                c.width = MIN(165,c.width);
                totalColWidth += c.width + colSpacing;
            }
        }
        CGFloat space = table.visibleRect.size.width - totalColWidth;
        NSMutableArray<WidthStats*>* expansions = [NSMutableArray array];
        NSMutableArray<WidthStats*>* shrinks = [NSMutableArray array];
        
        NSLog(@"%ld new columns. all columns width %f space left %f", newCols.count, totalColWidth, space);
        dispatch_queue_t gatherQ = dispatch_queue_create("QueryResultsTable.GatherQ", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_t workQ = dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0);
        dispatch_group_t group = dispatch_group_create();
        
        // Go through all the columns. Shrink any we can and keep track of the ones that should be made larger.
        NSDate *sizingStart = [NSDate date];
        for (NSTableColumn *c in newCols) {
            NSCell *cell = c.dataCell;
            NSFont *font = cell.font;
            dispatch_group_async(group, workQ, ^{
                NSMutableArray<NSString*>* values = [NSMutableArray arrayWithCapacity:qr.records.count+1];
                [values addObject:c.title];
                for (int r = 0 ; r < qr.records.count; r++) {
                    id v = [qr valueForFieldPath:c.identifier row:r];
                    if (v != nil) {
                        [values addObject:[v description]];
                    }
                }
                WidthStatsBuilder *stats = [[WidthStatsBuilder alloc] initWithMin:c.minWidth];
                stats.column = c;
                [stats addStrings:values font:font];
                WidthStats *ws = [stats resultsWithOffset:colSpacing];
                dispatch_sync(gatherQ, ^{
                    if (ws.max < c.width) {
                        [shrinks addObject:ws];
                    }
                    if (ws.headerWidth > c.width || ws.max > c.width) {
                        [expansions addObject:ws];
                    }
                });
            });
        }
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        NSDate *widthCalcEnd = [NSDate date];
        NSLog(@"calculating all column widths took %fms", [widthCalcEnd timeIntervalSinceDate:start] * 1000);

        for (WidthStats *ws in shrinks) {
            NSTableColumn *c = ws.column;
            space += c.width - ws.max;
            c.width = ws.max;
            // NSLog(@"col %@ shrunk to %f, space now %f", c.title, c.width, space);
        }
        NSLog(@"shrinking %ld columns widths took %fms", shrinks.count, [[NSDate date] timeIntervalSinceDate:widthCalcEnd] * 1000);
        
        typedef CGFloat(^sizeExtractor)(WidthStats*);
        CGFloat (^expander)(CGFloat, NSArray<WidthStats*>*, sizeExtractor) = ^CGFloat(CGFloat space, NSArray<WidthStats*>*cols, sizeExtractor sizer) {
            if (space <= 0) {
                return space;
            }
            NSLog(@"expander starting, space=%f", space);
            NSMutableArray<WidthStats*> *tosize = [NSMutableArray arrayWithCapacity:cols.count];
            for (WidthStats *stats in cols) {
                CGFloat newSize = sizer(stats);
                if (newSize <= stats.column.width) {
                    continue;
                }
                [tosize addObject:stats];
            }
            // Sort the updates by smallest additional amount to largest additional amount
            [tosize sortUsingComparator:^NSComparisonResult(WidthStats*  _Nonnull obj1, WidthStats*  _Nonnull obj2) {
                CGFloat a = sizer(obj1) - obj1.column.width;
                CGFloat b = sizer(obj2) - obj2.column.width;
                return a < b ? NSOrderedAscending : a == b ? NSOrderedSame : NSOrderedDescending;
            }];
            for (WidthStats *s in tosize) {
                CGFloat newSize = MIN(space + s.column.width, sizer(s));
                space -= (newSize - s.column.width);
                s.column.width = newSize;
                NSLog(@"col %@ grown to %f, space now %f", s.column.title, s.column.width, space);
                if (space <= 0) {
                    break;
                }
            }
            return space;
        };
        NSDate *expanderStart = [NSDate date];
        space = expander(space, expansions, ^CGFloat(WidthStats*s) {
            return s.percentile80;
        });
        space = expander(space, expansions, ^CGFloat(WidthStats*s) {
            return s.max - s.percentile80 < 100 ? s.max : s.percentile80;
        });
        space = expander(space, expansions, ^CGFloat(WidthStats*s) {
            return s.headerWidth;
        });
        space = expander(space, expansions, ^CGFloat(WidthStats*s) {
            return s.max;
        });

        NSLog(@"space remaining %f, table width %f", space, table.visibleRect.size.width);
        NSLog(@"expanding took %fms", [[NSDate date] timeIntervalSinceDate:expanderStart] * 1000);
        NSLog(@"sizing took %fms", [[NSDate date] timeIntervalSinceDate:start] * 1000);
    }
    return qcols.names;
}

@end

