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
#import "TStamp.h"

const NSInteger MIN_WIDTH = 40;
const NSInteger DEF_WIDTH = 100;
const NSInteger DEF_ID_WIDTH = 165;

@interface WidthStats : NSObject
@property (assign) NSInteger count;
@property (assign) NSInteger max;
@property (assign) NSInteger percentile80;
@property (assign) NSInteger headerWidth;
@property (assign) NSInteger width;
@property (retain) NSString *identifier;
@end

@implementation WidthStats
@end

@interface WidthStatsBuilder : NSObject {
    NSMutableString             *buffer;
    NSMutableArray<NSNumber*>   *vals;
    NSInteger                   minToConsider;
    NSInteger                   minCount;
    NSInteger                   headerWidth;
}
@property (retain) NSFont *font;
@property (retain) NSString *identifier;
@property (assign) NSInteger width;

-(instancetype)initWithId:(NSString*)i font:(NSFont*)f;
-(void)add:(NSString *)s;
-(WidthStats*)resultsWithOffset:(NSInteger)pad;

@end

@implementation WidthStatsBuilder

-(instancetype)initWithId:(NSString*)i font:(NSFont*)f {
    self = [super init];
    minToConsider = MIN_WIDTH;
    buffer = [NSMutableString stringWithCapacity:1024];
    vals = [NSMutableArray array];
    self.width = [i hasSuffix:@"Id"] ? DEF_ID_WIDTH : DEF_WIDTH;
    self.identifier = i;
    self.font = f;
    [self add:i];
    return self;
}

-(void)add:(NSString *)s {
    // For really long strings just treat them as a fixed amount.
    if (s.length > 85) {
        [vals addObject:@(550)];
        return;
    }
    [buffer appendString:s];
    [buffer appendString:@"\n"];
}

-(NSArray<NSNumber*>*)measureStrings {
    // see https://stackoverflow.com/questions/30537811/performance-of-measuring-text-width-in-appkit
    NSAttributedString *richText = [[NSAttributedString alloc]
                                        initWithString:buffer
                                        attributes:@{ NSFontAttributeName: self.font }];
    CGPathRef path = CGPathCreateWithRect(CGRectMake(0, 0, CGFLOAT_MAX, CGFLOAT_MAX), NULL);
    CTFramesetterRef setter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)richText);
    CTFrameRef frame = CTFramesetterCreateFrame(setter, CFRangeMake(0, buffer.length), path, NULL);
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
    [vals sortUsingSelector:@selector(compare:)];
    return vals;
}

-(WidthStats*)resultsWithOffset:(NSInteger)pad {
    [self measureStrings];
    WidthStats *r = [[WidthStats alloc] init];
    r.max = pad + (vals.count == 0 ? minToConsider : vals.lastObject.integerValue);
    r.count = vals.count + minCount;
    NSInteger p80Idx = 0.8 * r.count;
    r.percentile80 = pad + (p80Idx <= minCount ? minToConsider : vals[p80Idx-minCount].integerValue);
    r.headerWidth = pad + headerWidth;
    r.width = self.width;
    r.identifier = self.identifier;
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

    // TODO what about if the primary object type changes, should we reset all columns then?
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

-(NSTableColumn *)createTableColumnWithIdentifier:(NSString *)identifier label:(NSString*)label width:(CGFloat)width {
    NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:identifier];
    col.title = label;
    col.editable = YES;
    col.minWidth = MIN_WIDTH;
    col.width = width;
    col.resizingMask = NSTableColumnUserResizingMask | NSTableColumnAutoresizingMask;
    col.sortDescriptorPrototype = [[SObjectSortDescriptor alloc] initWithKey:identifier ascending:YES describer:self.describer];
    return col;
}

- (NSArray *)createTableColumns:(ZKQueryResult *)qr {
    QueryColumns *qcols = [[QueryColumns alloc] initWithResult:qr];
    
    TStamp *tstamp = [TStamp start];
    
    if (qcols.isSearchResult) {
        // TODO, should this be added to cols?
        [table addTableColumn:[self createTableColumnWithIdentifier:TYPE_COLUMN_IDENTIFIER label:@"Type" width:100]];
    }
    // TODO prevent re-ordering of delete/error column
    // TODO, better answer to this?
    NSTableColumn *dummy = [[NSTableColumn alloc] init];
    NSCell *dummyCell = dummy.dataCell;
    NSFont *font = dummyCell.font;
    
    NSMutableArray<WidthStatsBuilder*>* cols = [NSMutableArray arrayWithCapacity:qcols.names.count];
    for (NSString *colName in qcols.names) {
        WidthStatsBuilder *b = [[WidthStatsBuilder alloc] initWithId:colName font:font];
        NSTableColumn *existing = [table tableColumnWithIdentifier:colName];
        if (existing != nil) {
            b.width = existing.width;
        }
        [cols addObject:b];
    }

    // Calculate the best size of the columns.
    // This is way more annoying than i thought it'd be.
    CGFloat totalColWidth = [table tableColumnWithIdentifier:DELETE_COLUMN_IDENTIFIER].width;
    CGFloat colSpacing = table.intercellSpacing.width*2;
    for (WidthStatsBuilder *c in cols) {
        totalColWidth += c.width + colSpacing;
    }
    CGFloat space = table.visibleRect.size.width - totalColWidth;
    NSLog(@"%ld columns. all columns width %f space left %f", cols.count, totalColWidth, space);

    // This array once populated will be in the same order as cols. Array contains NSNull | WidthStats*
    NSMutableArray<id>* colWidths = [NSMutableArray arrayWithCapacity:cols.count];
    // This array is all in an arbitary order.
    NSMutableArray<WidthStats*>* expansions = [NSMutableArray array];

    // Measuring the required space to render a string is suprisingly expensive, and we've got a lot todo.
    // We'll farm out each column to a worker pool and gather up all the results.
    dispatch_queue_t gatherQ = dispatch_queue_create("QueryResultsTable.GatherQ", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_t workQ = dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0);
    dispatch_group_t group = dispatch_group_create();
    
    // Go through all the columns. Calculate stats about the column values. Collect up the results in colWidths.
    NSNull *null = [NSNull null];
    while (colWidths.count < cols.count) {
        [colWidths addObject:null];
    }
    [cols enumerateObjectsUsingBlock:^(WidthStatsBuilder * _Nonnull col, NSUInteger idx, BOOL * _Nonnull stop) {
        dispatch_group_async(group, workQ, ^{
            for (int r = 0 ; r < qr.records.count; r++) {
                id v = [qr valueForFieldPath:col.identifier row:r];
                if (v != nil) {
                    [col add:[v description]];
                }
            }
            WidthStats *ws = [col resultsWithOffset:colSpacing];
            dispatch_sync(gatherQ, ^{
                colWidths[idx] = ws;
                if (ws.headerWidth > ws.width || ws.headerWidth > ws.max || ws.max > ws.width) {
                    [expansions addObject:ws];
                }
            });
        });
    }];
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    [tstamp mark:@"calc'd column content widths"];

    for (WidthStats *ws in colWidths) {
        if (ws.max < ws.width) {
            space += ws.width - ws.max;
            ws.width = ws.max;
        }
    }
    
    typedef CGFloat(^sizeExtractorFn)(WidthStats*);
    typedef CGFloat(^expanderFn)(CGFloat, NSArray<WidthStats*>*, sizeExtractorFn);
    expanderFn expander = ^CGFloat(CGFloat space, NSArray<WidthStats*>*cols, sizeExtractorFn sizer) {
        if (space <= 0) {
            return space;
        }
        NSLog(@"expander starting, space=%f, %ld potential expansions", space, cols.count);
        NSMutableArray<WidthStats*> *tosize = [NSMutableArray arrayWithCapacity:cols.count];
        for (WidthStats *stats in cols) {
            CGFloat newSize = sizer(stats);
            if (newSize <= stats.width) {
                continue;
            }
            [tosize addObject:stats];
        }
        // Sort the updates by smallest additional amount to largest additional amount
        [tosize sortUsingComparator:^NSComparisonResult(WidthStats*  _Nonnull obj1, WidthStats*  _Nonnull obj2) {
            CGFloat a = sizer(obj1) - obj1.width;
            CGFloat b = sizer(obj2) - obj2.width;
            return a < b ? NSOrderedAscending : a == b ? NSOrderedSame : NSOrderedDescending;
        }];
        for (WidthStats *s in tosize) {
            CGFloat newSize = MIN(space + s.width, sizer(s));
            space -= (newSize - s.width);
            s.width = newSize;
            NSLog(@"col %@ grown to %ld, space now %f", s.identifier, s.width, space);
            if (space <= 0) {
                break;
            }
        }
        return space;
    };
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
    [tstamp mark:@"calc col widths"];
    
    // Add/order the columns in the table.
    
    // Rather than trying to resize, insert, shuffle the table columns to keep the identifiers
    // constant, we'll update the columns to match what we want.
    
    // remove any unwanted columns
    while (table.tableColumns.count > 2 + cols.count) {
        [table removeTableColumn:table.tableColumns[2]];
    }
    NSInteger idx = 2;
    for (WidthStats *s in colWidths) {
        if (idx < table.tableColumns.count) {
            NSTableColumn *dest = table.tableColumns[idx];
            dest.minWidth = MIN_WIDTH;
            dest.width = s.width;
            dest.title = s.identifier;
            dest.identifier = s.identifier;
            dest.sortDescriptorPrototype = [[SObjectSortDescriptor alloc] initWithKey:s.identifier
                                                                            ascending:YES
                                                                            describer:self.describer];
        } else {
            NSTableColumn *dest = [self createTableColumnWithIdentifier:s.identifier label:s.identifier width:s.width];
            [table addTableColumn:dest];
        }
        idx++;
    }
    
    [tstamp mark:@"updating tableView columns"];
    [tstamp log];
    return qcols.names;
}

@end

