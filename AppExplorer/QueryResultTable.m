// Copyright (c) 2008,2012,2014 Simon Fell
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
#import "zkSObject.h"
#import "ZKQueryResult.h"
#import "EditableQueryResultWrapper.h"
#import "SearchQueryResult.h"
#import "ZKAddress.h"

@interface QueryResultTable ()
- (NSArray *)createTableColumns:(ZKQueryResult *)qr;
- (NSArray *)buildColumnListFromQueryResult:(ZKQueryResult *)qr;
@end

@interface QueryColumn : NSObject {
    NSString        *name;
    NSMutableArray    *childCols; // of QueryColumn
}
@end

@implementation QueryColumn
-(instancetype)initWithName:(NSString *)n {
    self = [super init];
    name = [n copy];
    childCols = nil;
    return self;
}


+(QueryColumn *)columnWithName:(NSString *)name {
    return [[QueryColumn alloc] initWithName:name];
}

-(NSString *)name {
    return name;
}

-(BOOL)isEqual:(id)anObject {
    return [name isEqualToString:[anObject name]];
}

-(void)addChildCol:(QueryColumn *)c {
    if (childCols == nil) {
        childCols = [NSMutableArray array];
        [childCols addObject:c];
        return;
    }
    if (![childCols containsObject:c])
        [childCols addObject:c];
}

-(void)addChildCols:(NSArray *)cols {
    for (QueryColumn *c in cols)
        [self addChildCol:c];
}

-(void)addChildColWithNames:(NSArray *)childNames {
    for (NSString *cn in childNames) {
        [self addChildCol:[QueryColumn columnWithName:[name stringByAppendingFormat:@".%@", cn]]];
    }
}

-(NSArray *)allNames {
    if (childCols == nil) return @[name];
    NSMutableArray *c = [NSMutableArray arrayWithCapacity:childCols.count];
    for (QueryColumn *qc in childCols)
        [c addObjectsFromArray:[qc allNames]];
    return c;
}

-(BOOL)hasChildNames {
    return childCols != nil;
}

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
    return queryResult;
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
    [table reloadData];
}

-(void)showHideErrorColumn {
    NSTableColumn *ec = [table tableColumnWithIdentifier:ERROR_COLUMN_IDENTIFIER];
    BOOL hasErrors = [wrapper hasErrors];
    ec.hidden = !hasErrors;
}

- (void)setQueryResult:(ZKQueryResult *)qr {
    if (qr == queryResult) return;
    [wrapper removeObserver:self forKeyPath:@"hasCheckedRows"];
    [self willChangeValueForKey:@"hasCheckedRows"];
    queryResult = qr;
    wrapper = [[EditableQueryResultWrapper alloc] initWithQueryResult:qr];
    [self didChangeValueForKey:@"hasCheckedRows"];
    [wrapper addObserver:self forKeyPath:@"hasCheckedRows" options:0 context:nil];
    int idxToDelete=0;
    while (table.numberOfColumns > 2) {
        NSString *colId = table.tableColumns[idxToDelete].identifier; 
        if ([colId isEqualToString:DELETE_COLUMN_IDENTIFIER] || [colId isEqualToString:ERROR_COLUMN_IDENTIFIER]) {
            idxToDelete++;
            continue;
        }
        [table removeTableColumn:table.tableColumns[idxToDelete]];
    }
    NSArray *cols = [self createTableColumns:qr];
    [wrapper setEditable:[cols containsObject:@"Id"]];
    [self updateTable];
}

-(void)replaceQueryResult:(ZKQueryResult *)qr {
    queryResult = qr;
    [wrapper setQueryResult:queryResult];
    [self showHideErrorColumn];
    [table reloadData];
}

- (void)removeRowAtIndex:(int)row {
    if (row >= [wrapper records].count) return;
    id ctx = [wrapper createMutatingRowsContext];
    [wrapper remmoveRowAtIndex:row context:ctx];
    [wrapper updateRowsFromContext:ctx];
    [self updateTable];
}

- (NSTableColumn *)createTableColumnWithIdentifier:(NSString *)identifier label:(NSString *)label {
    NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:identifier];
    col.headerCell.stringValue = label;
    [col setEditable:YES];
    col.resizingMask = NSTableColumnUserResizingMask | NSTableColumnAutoresizingMask;
    if ([identifier hasSuffix:@"Id"])
        col.width = 165;
    return col;
}

- (NSArray *)createTableColumns:(ZKQueryResult *)qr {
    NSArray *cols = [self buildColumnListFromQueryResult:qr];
    for (NSString *colName in cols) {
        NSTableColumn *col = [self createTableColumnWithIdentifier:colName label:colName];
        [table addTableColumn:col];
    }
    return cols;
}

// looks to see if the queryColumn already exists in the columns collection, its returned if it is
// otherwise it's added to the collection.
// so in either case, the return value is the QueryColumn instance that is in the columns collection.
- (QueryColumn *)getOrAddQueryColumn:(QueryColumn *)qc fromList:(NSMutableArray *)columns {
    NSUInteger idx = [columns indexOfObject:qc];
    if (idx == NSNotFound) {
        [columns addObject:qc];
        return qc;
    }
    return columns[idx];
}

- (BOOL)addColumnsFromSObject:(ZKSObject *)row withPrefix:(NSString *)prefix toList:(NSMutableArray *)columns {
    BOOL seenNull = NO;
    
    for (NSString *fn in [row orderedFieldNames]) {
        NSObject *val = [row fieldValue:fn];
        if (val == nil || val == [NSNull null]) {
            seenNull = YES;
        }
        NSString *fullName = prefix.length > 0 ? [NSString stringWithFormat:@"%@.%@", prefix, fn] : fn;
        QueryColumn *qc = [self getOrAddQueryColumn:[QueryColumn columnWithName:fullName] fromList:columns];
        if ([val isKindOfClass:[ZKAddress class]]) {
            if (![qc hasChildNames])
                [qc addChildColWithNames:@[@"street", @"city", @"state", @"stateCode", @"country", @"countryCode", @"postalCode", @"longitude", @"latitude"]];

        } else if ([val isKindOfClass:[ZKLocation class]]) {
            if (![qc hasChildNames])
                [qc addChildColWithNames:@[@"longitude", @"latitude"]];

        } else if ([val isKindOfClass:[ZKSObject class]]) {
            if (![qc hasChildNames]) {
                NSMutableArray *relatedColumns = [NSMutableArray array];
                seenNull |= [self addColumnsFromSObject:(ZKSObject *)val withPrefix:fullName toList:relatedColumns];
                [qc addChildCols:relatedColumns];
            }
        }
    }
    return seenNull;
}

- (NSArray *)buildColumnListFromQueryResult:(ZKQueryResult *)qr {
    NSMutableArray *columns = [NSMutableArray array];
    NSMutableSet *processedTypes = [NSMutableSet set];
    BOOL isSearchResult = [qr conformsToProtocol:@protocol(IsSearchQueryResult)];
    
    for (ZKSObject *row in [qr records]) {
        // in the case we're looking at search results, we need to get columns for each distinct type.
        if ([processedTypes containsObject:[row type]]) continue;
        
        // if we didn't see any null columns, then there's no need to look at any further rows.
        if (![self addColumnsFromSObject:row withPrefix:nil toList:columns]) {
            if (!isSearchResult) break; // all done.
            [processedTypes addObject:[row type]];
        }
    }
    // now flatten the queryColumns into a set of real columns
    NSMutableArray *colNames = [NSMutableArray arrayWithCapacity:columns.count + 1];

    if (isSearchResult)
        [table addTableColumn:[self createTableColumnWithIdentifier:@"SObject__Type" label:@"Type"]];
    
    for (QueryColumn *qc in columns)
        [colNames addObjectsFromArray:[qc allNames]];
        
    return colNames;
}

@end
