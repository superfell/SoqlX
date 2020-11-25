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
    BOOL hasErrors = [wrapper hasErrors];
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
    [wrapper setQueryResult:qr];
    [self showHideErrorColumn];
}

- (void)removeRowWithId:(NSString *)recordId {
    [wrapper removeRowWithId:recordId];
    [self updateTable];
}

- (NSTableColumn *)createTableColumnWithIdentifier:(NSString *)identifier label:(NSString *)label {
    NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:identifier];
    col.headerCell.stringValue = label;
    [col setEditable:YES];
    col.resizingMask = NSTableColumnUserResizingMask | NSTableColumnAutoresizingMask;
    if ([identifier hasSuffix:@"Id"])
        col.width = 165;
    col.sortDescriptorPrototype = [[SObjectSortDescriptor alloc] initWithKey:identifier ascending:YES describer:self.describer];
    return col;
}

- (NSArray *)createTableColumns:(ZKQueryResult *)qr {
    QueryColumns *qcols = [[QueryColumns alloc] initWithResult:qr];
    if (qcols.isSearchResult) {
        [table addTableColumn:[self createTableColumnWithIdentifier:TYPE_COLUMN_IDENTIFIER label:@"Type"]];
    }
    for (NSString *colName in qcols.names) {
        NSTableColumn *col = [self createTableColumnWithIdentifier:colName label:colName];
        [table addTableColumn:col];
    }
    return qcols.names;
}

@end
