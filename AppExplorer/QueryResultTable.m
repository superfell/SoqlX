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
@property (retain) NSString *label;
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
@property (retain) NSString *label;
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
    r.label = self.label;
    return r;
}

@end

@interface QueryResultTable ()
- (NSArray<NSString*> *)createTableColumns:(ZKQueryResult *)qr;
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

-(void)replaceQueryResult:(ZKQueryResult *)qr {
    [wrapper setQueryResult:qr];
    [self showHideErrorColumn];
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

    QueryColumns *qcols = [[QueryColumns alloc] initWithResult:qr];
    // TODO prevent re-ordering of delete/error column
    // TODO, better answer to this?
    NSTableColumn *dummy = [[NSTableColumn alloc] init];
    NSCell *dummyCell = dummy.dataCell;
    NSFont *font = dummyCell.font;
    
    // Adding, removing, resizing NSTableView columns cause an expensive relayout calc to be triggered.
    // There's no way to batch these up and do the layout once. So rather than working directly with the
    // tableview columns, we do all our calculations with a separate object, and then apply to the results
    // to the table at the end.

    WidthStatsBuilder*(^newBuilder)(NSString*) = ^WidthStatsBuilder*(NSString*colName) {
        WidthStatsBuilder *b = [[WidthStatsBuilder alloc] initWithId:colName font:font];
        NSTableColumn *existing = [self->table tableColumnWithIdentifier:colName];
        if (existing != nil) {
            b.width = existing.width;
            b.label = existing.title;
        }
        return b;
    };
    NSMutableArray<WidthStatsBuilder*>* cols = [NSMutableArray arrayWithCapacity:qcols.names.count+1];
    if (qcols.isSearchResult) {
        WidthStatsBuilder*c = newBuilder(TYPE_COLUMN_IDENTIFIER);
        c.label = @"Type";
        [cols addObject:c];
    }
    for (NSString *colName in qcols.names) {
        [cols addObject:newBuilder(colName)];
    }

    // Calculate the best size of the columns. This is way more annoying than i thought it'd be.
    // This take a few steps, the last 4 are the same except different widths are applied.
    //
    //  1. calculate the width of the column contents, and separatly the column title.
    //  2. shrink any columns who's current width is more than needed for the max content width.
    //  3. if there's space remaining, expand columns to their 80% percentile content width
    //  4. if there's space remaining, expand columns to their max content width, unless the
    //          max is a lot larger than the 80% percentile
    //  5. if there's space remaining, expand columns so that their titles fit fully.
    //  6. if there's space remaining, expand columns to their max content width.
    
    CGFloat totalColWidth = [table tableColumnWithIdentifier:DELETE_COLUMN_IDENTIFIER].width;
    CGFloat colSpacing = table.intercellSpacing.width*2;
    for (WidthStatsBuilder *c in cols) {
        totalColWidth += c.width + colSpacing;
    }
    CGFloat space = table.visibleRect.size.width - totalColWidth;
    //NSLog(@"%ld columns. all columns width %f space left %f", cols.count, totalColWidth, space);

    // This array once populated will be in the same order as cols. Array contains NSNull | WidthStats*
    NSMutableArray<id>* colWidths = [NSMutableArray arrayWithCapacity:cols.count];
    // This array is in an arbitary order.
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
                id v = [self->wrapper columnValue:col.identifier atRow:r];
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
        // NSLog(@"expander starting, space=%f, %ld potential expansions", space, cols.count);
        NSMutableArray<WidthStats*> *resize = [NSMutableArray arrayWithCapacity:cols.count];
        for (WidthStats *stats in cols) {
            CGFloat newSize = sizer(stats);
            if (newSize <= stats.width) {
                continue;
            }
            [resize addObject:stats];
        }
        // Sort the updates by smallest additional amount to largest additional amount
        // TODO, do we want to try and restrict this to just columns that are visible initially?
        [resize sortUsingComparator:^NSComparisonResult(WidthStats*  _Nonnull obj1, WidthStats*  _Nonnull obj2) {
            CGFloat a = sizer(obj1) - obj1.width;
            CGFloat b = sizer(obj2) - obj2.width;
            return a < b ? NSOrderedAscending : a == b ? NSOrderedSame : NSOrderedDescending;
        }];
        for (WidthStats *s in resize) {
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
    // NSLog(@"space remaining %f, table width %f", space, table.visibleRect.size.width);
    [tstamp mark:@"calc col widths"];
    
    // Finally add/update the NSTableColumns in the table to reflect the calculated columns/sizes
    
    // remove any unwanted columns
    while (table.tableColumns.count > 2 + cols.count) {
        [table removeTableColumn:table.tableColumns[2]];
    }
    NSInteger idx = 2;
    for (WidthStats *s in colWidths) {
        NSTableColumn *dest;
        if (idx < table.tableColumns.count) {
            dest = table.tableColumns[idx];
        } else {
            dest = [[NSTableColumn alloc] initWithIdentifier:s.identifier];
        }
        [self setTableColumn:dest toIdentifier:s.identifier label:s.label width:s.width];
        if (dest.tableView == nil) {
            [table addTableColumn:dest];
        }
        idx++;
    }
    
    [tstamp mark:@"updating tableView columns"];
    [tstamp log];
    return qcols.names;
}

@end

