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
#import "ZKQueryResult+Display.h"


const NSInteger MIN_WIDTH = 40;
const NSInteger DEF_WIDTH = 100;
const NSInteger DEF_ID_WIDTH = 165;

@interface ColumnResult : NSObject
@property (assign) NSInteger count;
@property (assign) NSInteger max;
@property (assign) NSInteger percentile80;
@property (assign) NSInteger headerWidth;
@property (assign) NSInteger width;
@property (retain) NSString *identifier;
@property (retain) NSString *label;
@end

@implementation ColumnResult
@end

@interface ColumnBuilder : NSObject {
    NSMutableString             *buffer;
    NSMutableArray<NSNumber*>   *vals;
    NSInteger                   minToConsider;
    NSInteger                   minCount;
    NSInteger                   headerWidth;
}
@property (retain) NSFont *font;
@property (retain) NSString *identifier;
@property (retain) NSString *label;
@property (assign) NSInteger width;

-(instancetype)initWithId:(NSString*)i font:(NSFont*)f;
-(void)add:(NSString *)s;
-(ColumnResult*)resultsWithOffset:(NSInteger)pad;

@end

@implementation ColumnBuilder

-(instancetype)initWithId:(NSString*)i font:(NSFont*)f {
    self = [super init];
    minToConsider = MIN_WIDTH;
    buffer = [NSMutableString stringWithCapacity:1024];
    vals = [NSMutableArray array];
    self.width = [i hasSuffix:@"Id"] ? DEF_ID_WIDTH : DEF_WIDTH;
    self.identifier = i;
    self.label = i;
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

-(void)measureStrings {
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
}

-(ColumnResult*)resultsWithOffset:(NSInteger)pad {
    [self measureStrings];
    ColumnResult *r = [[ColumnResult alloc] init];
    r.max = pad + (vals.count == 0 ? minToConsider : vals.lastObject.integerValue);
    r.count = vals.count + minCount;
    NSInteger p80Idx = 0.8 * r.count;
    r.percentile80 = pad + (p80Idx <= minCount ? minToConsider : vals[p80Idx-minCount].integerValue);
    r.headerWidth = pad + headerWidth;
    r.width = self.width;
    r.identifier = self.identifier;
    r.label = self.label;
    return r;
}

@end

@interface QueryResultTable ()
-(NSArray<NSString*> *)createTableColumns:(ZKQueryResult *)qr;
-(NSFont *)tableCellFont;
-(NSArray<ColumnResult*>*)measureColumns:(NSArray<ColumnBuilder*>*) cols spacing:(CGFloat)colSpacing contents:(ZKQueryResult*)qr;
-(CGFloat)sizeColumnsToBestFit:(NSArray<ColumnResult*>*)cols space:(CGFloat)space;

@property (strong) QueryColumns *columns;
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

    [table tableColumnWithIdentifier:ERROR_COLUMN_IDENTIFIER].hidden = TRUE;
    NSArray<NSString*>* cols = [self createTableColumns:qr];
    [wrapper setEditable:[cols containsObject:@"Id"]];
    [self updateTable];
}

-(void)addQueryMoreResults:(ZKQueryResult *)qr {
    TStamp *tstamp = [TStamp start];
    NSMutableArray *allRecs = [NSMutableArray arrayWithCapacity:self.queryResult.records.count + qr.records.count];
    [allRecs addObjectsFromArray:self.queryResult.records];
    [allRecs addObjectsFromArray:[qr records]];
    ZKQueryResult * total = [[ZKQueryResult alloc] initWithRecords:allRecs
                                                              size:qr.size
                                                              done:qr.done
                                                      queryLocator:qr.queryLocator];
    [tstamp mark:@"built new qr"];
    // Because the columns are derived from the query results, we have to check to see if there are any new
    // columns. If so, we want to add those to the table, but not recalculate all the existing columns.
    QueryColumns *qcols = [[QueryColumns alloc] initWithResult:total];
    [tstamp mark:@"extracted cols from qr"];
    
    // We can't just compare the lengths to see if they're the same. Queries like
    // select id,name,foo__r.bar__c from XXXX can have the first batch have null for foo__r
    // (so resulting columns id,name,foo__r) and then the second batch can have foo__r populated
    // (so resulting columns id,name,foo__r.bar__c). In both cases we'll think theres
    // 3 columns

    NSMutableArray<ColumnBuilder*> *newColumns = [NSMutableArray arrayWithCapacity:qcols.count-self.columns.count];
    NSMutableArray<NSNumber *> *newColIndexes = [NSMutableArray arrayWithCapacity:qcols.count-self.columns.count];
    NSFont *font = [self tableCellFont];
    NSSet<NSString*> *existingNames = [NSSet setWithArray:self.columns.names];
    [qcols.names enumerateObjectsUsingBlock:^(NSString * _Nonnull colName, NSUInteger idx, BOOL * _Nonnull stop) {
        if (![existingNames containsObject:colName]) {
            ColumnBuilder *b = [[ColumnBuilder alloc] initWithId:colName font:font];
            [newColIndexes addObject:@(idx)];
            [newColumns addObject:b];
        }
    }];

    [tstamp mark:@"determined new cols"];
    // We know there are no values for these columns in the rows before the new chunk, so we only
    // need to measure the new chunk, not the entire results.
    NSArray<ColumnResult*>* colResults = [self measureColumns:newColumns
                                                      spacing:self.table.intercellSpacing.width
                                                     contents:qr];
    [tstamp mark:@"calc content widths"];
    // There are edge cases where an existing column goes away, (e.g. a related object was null and now has data)
    // so deal with that.
    NSSet<NSString*>* newColSet = [NSSet setWithArray:qcols.names];
    for (NSString *oldCol in existingNames) {
        if (![newColSet containsObject:oldCol]) {
            [table removeTableColumn:[table tableColumnWithIdentifier:oldCol]];
        }
    }
    [tstamp mark:@"removed columns"];
    CGFloat space = table.visibleRect.size.width;
    for (NSTableColumn *c in table.tableColumns) {
        if (!c.isHidden) {
            space -= c.width;
        }
    }
    space = [self sizeColumnsToBestFit:colResults space:space];
    [tstamp mark:@"calc'd col widths"];
    // Annoyingly we can't insert a new column where we want it, we have to add it to the end
    // then move it. We work backwards otherwise the calculated indexes will be off once a column
    // is added.
    NSInteger numSpecialColumns = wrapper.allSystemColumnIdentifiers.count;
    [colResults enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(ColumnResult * _Nonnull col, NSUInteger idx, BOOL * _Nonnull stop) {
        NSTableColumn *tc = [[NSTableColumn alloc] initWithIdentifier:col.identifier];
        [self setTableColumn:tc toIdentifier:col.identifier label:col.label width:col.width];
        [table addTableColumn:tc];
        NSInteger destColIdx = newColIndexes[idx].integerValue + numSpecialColumns;
        NSInteger currColIdx = table.tableColumns.count-1;
        NSLog(@"new column for %@ idx=%ld. currIdx=%ld target=%ld", col.identifier, idx, currColIdx, destColIdx);
        if (destColIdx != currColIdx) {
            [table moveColumn:currColIdx toColumn:destColIdx];
        }
    }];
    [tstamp mark:@"added TV Columns"];
    [tstamp log];
    self.columns = qcols;
    self.wrapper.queryResult = total;
    [self updateTable];
}

- (void)removeRowsWithIds:(NSSet<NSString*> *)recordIds {
    [wrapper removeRowsWithIds:recordIds];
    [self updateTable];
}

-(void)setTableColumn:(NSTableColumn*)c toIdentifier:(NSString *)identifier label:(NSString*)label width:(CGFloat)width {
    c.identifier = identifier;
    c.title = label;
    c.editable = YES;
    c.minWidth = MIN_WIDTH;
    c.width = width;
    c.resizingMask = NSTableColumnUserResizingMask | NSTableColumnAutoresizingMask;
    c.sortDescriptorPrototype = [[SObjectSortDescriptor alloc] initWithKey:identifier ascending:YES describer:self.describer];
}

- (NSArray<NSString*> *)createTableColumns:(ZKQueryResult *)qr {
    TStamp *tstamp = [TStamp start];

    self.columns = [[QueryColumns alloc] initWithResult:qr];
    [tstamp mark:@"extracted cols from qr"];
    NSFont *font = [self tableCellFont];
    
    // Adding, removing, resizing NSTableView columns cause an expensive relayout calc to be triggered.
    // There's no way to batch these up and do the layout once. So rather than working directly with the
    // tableview columns, we do all our calculations with a separate object, and then apply to the results
    // to the table at the end.

    ColumnBuilder*(^newColumn)(NSString*) = ^ColumnBuilder*(NSString*colName) {
        ColumnBuilder *b = [[ColumnBuilder alloc] initWithId:colName font:font];
        NSTableColumn *existing = [self->table tableColumnWithIdentifier:colName];
        if (existing != nil) {
            b.width = existing.width;
            b.label = existing.title;
        }
        return b;
    };
    NSMutableArray<ColumnBuilder*>* cols = [NSMutableArray arrayWithCapacity:self.columns.names.count+1];
    if (self.columns.isSearchResult) {
        ColumnBuilder *c = newColumn(TYPE_COLUMN_IDENTIFIER);
        c.label = @"Type";
        [cols addObject:c];
    }
    for (NSString *colName in self.columns.names) {
        [cols addObject:newColumn(colName)];
    }

    CGFloat totalColWidth = [table tableColumnWithIdentifier:DELETE_COLUMN_IDENTIFIER].width;
    CGFloat colSpacing = table.intercellSpacing.width*2;
    for (ColumnBuilder *c in cols) {
        totalColWidth += c.width + colSpacing;
    }
    CGFloat space = table.visibleRect.size.width - totalColWidth;
    //NSLog(@"%ld columns. all columns width %f space left %f", cols.count, totalColWidth, space);

    // This array is in the same order as cols.
    NSArray<ColumnResult*>* colResults = [self measureColumns:cols spacing:colSpacing contents:qr];
    [tstamp mark:@"calc'd column content widths"];

    space = [self sizeColumnsToBestFit:colResults space:space];
    // NSLog(@"space remaining %f, table width %f", space, table.visibleRect.size.width);
    [tstamp mark:@"calc col widths"];
    
    // Finally add/update the NSTableColumns in the table to reflect the calculated columns/sizes
    
    // remove any unwanted columns
    NSInteger numFixedColumns = wrapper.allSystemColumnIdentifiers.count;
    while (table.tableColumns.count > numFixedColumns + cols.count) {
        [table removeTableColumn:table.tableColumns[numFixedColumns]];
    }
    NSInteger idx = numFixedColumns;
    for (ColumnResult *c in colResults) {
        NSTableColumn *dest;
        if (idx < table.tableColumns.count) {
            dest = table.tableColumns[idx];
        } else {
            dest = [[NSTableColumn alloc] initWithIdentifier:c.identifier];
        }
        [self setTableColumn:dest toIdentifier:c.identifier label:c.label width:c.width];
        if (dest.tableView == nil) {
            [table addTableColumn:dest];
        }
        idx++;
    }
    
    [tstamp mark:@"updating tableView columns"];
    [tstamp log];
    return self.columns.names;
}

// Measures the width of the content of the provided set of columns and returns the results. The results array
// is in the same order as the input array.
-(NSArray<ColumnResult*>*)measureColumns:(NSArray<ColumnBuilder*>*) cols spacing:(CGFloat)colSpacing contents:(ZKQueryResult*)qr {
    if (cols.count == 0) {
        return [NSArray array];
    }
    NSMutableArray<id>* colResults = [NSMutableArray arrayWithCapacity:cols.count];
    NSNull *null = [NSNull null];
    while (colResults.count < cols.count) {
        [colResults addObject:null];
    }

    // Measuring the required space to render a string is suprisingly expensive, and we've got a lot todo.
    // We'll farm out each column to a worker pool and gather up all the results.
    dispatch_queue_t gatherQ = dispatch_queue_create("QueryResultsTable.GatherQ", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_t workQ = dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0);
    dispatch_group_t group = dispatch_group_create();

    [cols enumerateObjectsUsingBlock:^(ColumnBuilder * _Nonnull col, NSUInteger idx, BOOL * _Nonnull stop) {
        dispatch_group_async(group, workQ, ^{
            NSArray<NSString*>* colPath = [col.identifier componentsSeparatedByString:@"."];
            for (int r = 0 ; r < qr.records.count; r++) {
                id v = [qr columnPathDisplayValue:colPath atRow:r];
                if (v != nil) {
                    [col add:[v description]];
                }
            }
            ColumnResult *ws = [col resultsWithOffset:colSpacing];
            dispatch_sync(gatherQ, ^{
                colResults[idx] = ws;
            });
        });
    }];
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    return colResults;
}

// Will set the size of the provided columns based on the size of the contents
// and the available free space. Returns the free space left after the sizes are set.
-(CGFloat)sizeColumnsToBestFit:(NSArray<ColumnResult*>*)cols space:(CGFloat)space {

    // Calculate the best size of the columns. This is way more annoying than i thought it'd be.
    // This take a few steps, the last 4 are the same except different widths are applied.
    //
    //  1. shrink any columns who's current width is more than needed for the max content width.
    //  2. if there's space remaining, expand columns to their 80th percentile content width
    //  3. if there's space remaining, expand columns to their max content width, unless the
    //          max is a lot larger than the 80th percentile
    //  4. if there's space remaining, expand columns so that their titles fit fully.
    //  5. if there's space remaining, expand columns to their max content width.

    NSMutableArray<ColumnResult*>* expansions = [NSMutableArray array];
    for (ColumnResult *c in cols) {
        if (c.max < c.width) {
            space += c.width - c.max;
            c.width = c.max;
        }
        if (c.headerWidth > c.width || c.headerWidth > c.max || c.max > c.width) {
            [expansions addObject:c];
        }
    }
    
    typedef CGFloat(^sizeExtractorFn)(ColumnResult*);
    typedef CGFloat(^expanderFn)(CGFloat, NSArray<ColumnResult*>*, sizeExtractorFn);
    expanderFn expander = ^CGFloat(CGFloat space, NSArray<ColumnResult*>*cols, sizeExtractorFn sizer) {
        if (space <= 0 || cols.count == 0) {
            return space;
        }
        // NSLog(@"expander starting, space=%f, %ld potential expansions", space, cols.count);
        NSMutableArray<ColumnResult*> *resize = [NSMutableArray arrayWithCapacity:cols.count];
        for (ColumnResult *col in cols) {
            CGFloat newSize = sizer(col);
            if (newSize <= col.width) {
                continue;
            }
            [resize addObject:col];
        }
        // Sort the updates by smallest additional amount to largest additional amount
        // TODO: do we want to try and restrict this to just columns that are visible initially?
        [resize sortUsingComparator:^NSComparisonResult(ColumnResult*  _Nonnull obj1, ColumnResult*  _Nonnull obj2) {
            CGFloat a = sizer(obj1) - obj1.width;
            CGFloat b = sizer(obj2) - obj2.width;
            return a < b ? NSOrderedAscending : a == b ? NSOrderedSame : NSOrderedDescending;
        }];
        for (ColumnResult *s in resize) {
            CGFloat newSize = fmin(space + s.width, sizer(s));
            space -= (newSize - s.width);
            s.width = newSize;
            //NSLog(@"col %@ grown to %ld, space now %f", s.identifier, s.width, space);
            if (space <= 0) {
                break;
            }
        }
        return space;
    };
    space = expander(space, expansions, ^CGFloat(ColumnResult*s) {
        return s.percentile80;
    });
    space = expander(space, expansions, ^CGFloat(ColumnResult*s) {
        return s.max - s.percentile80 < 100 ? s.max : s.percentile80;
    });
    space = expander(space, expansions, ^CGFloat(ColumnResult*s) {
        return s.headerWidth;
    });
    space = expander(space, expansions, ^CGFloat(ColumnResult*s) {
        return s.max;
    });
    // NSLog(@"space remaining %f, table width %f", space, table.visibleRect.size.width);
    return space;
}

-(NSFont*)tableCellFont {
    // TODO, better answer to this?
    NSTableColumn *dummy = [[NSTableColumn alloc] init];
    NSCell *dummyCell = dummy.dataCell;
    NSFont *font = dummyCell.font;
    return font;
}

@end

