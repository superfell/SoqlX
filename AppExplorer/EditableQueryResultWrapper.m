// Copyright (c) 2007-2015,2018,2020 Simon Fell
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

#import "EditableQueryResultWrapper.h"
#import "QueryResultCell.h"
#import <ZKSforce/ZKSforce.h>
#import "SObject.h"

@implementation EditableQueryResultWrapper

+(NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
    NSSet *paths = [super keyPathsForValuesAffectingValueForKey:key];
    if ([key isEqualToString:@"hasCheckedRows"])
        return [paths setByAddingObject:@"queryResult"];
    if ([key isEqualToString:@"hasErrors"])
        return [paths setByAddingObject:@"queryResult"];
    return paths;
}

- (instancetype)initWithQueryResult:(ZKQueryResult *)qr {
    self = [super init];
    self.queryResult = qr;
    self.editable = NO;
    imageCell = [[QueryResultCell alloc] initTextCell:@""];
    return self;
}

- (NSUInteger)removeRowsWithIds:(NSSet<NSString*>*)recordIds {
    NSArray *filtered = [self.queryResult.records filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        return ![recordIds containsObject:[evaluatedObject id]];
    }]];
    NSUInteger removedCount = self.queryResult.records.count - filtered.count;
    if (removedCount > 0) {
        ZKQueryResult *before = self.queryResult;
        ZKQueryResult *nr = [[ZKQueryResult alloc] initWithRecords:filtered size:before.size-removedCount done:before.done queryLocator:before.queryLocator];
        [self setQueryResult:nr];
    }
    return removedCount;
}

-(NSArray *)allSystemColumnIdentifiers {
    return @[DELETE_COLUMN_IDENTIFIER, ERROR_COLUMN_IDENTIFIER];
}

- (BOOL)hasCheckedRows {
    for (ZKSObject *row in self.queryResult.records) {
        if (row.checked) {
            return YES;
        }
    }
    return NO;
}

- (void)setChecksOnAllRows:(BOOL)checked {
    [self willChangeValueForKey:@"hasCheckedRows"];
    for (ZKSObject *row in self.queryResult.records) {
        row.checked = checked;
    }
    [self didChangeValueForKey:@"hasCheckedRows"];
}

- (void)setChecked:(BOOL)checked onRowWithIndex:(NSUInteger)index {
    [self willChangeValueForKey:@"hasCheckedRows"];
    ZKSObject *row = self.queryResult.records[index];
    row.checked = checked;
    [self didChangeValueForKey:@"hasCheckedRows"];
}

- (BOOL)hasErrors {
    for (ZKSObject *row in self.queryResult.records) {
        if (row.errorMsg.length > 0) {
            return YES;
        }
    }
    return NO;
}

- (void)clearErrors {
    [self willChangeValueForKey:@"hasErrors"];
    for (ZKSObject *row in self.queryResult.records) {
        row.errorMsg = nil;
    }
    [self didChangeValueForKey:@"hasErrors"];
}

- (void)addError:(NSString *)errMsg onRowWithRowIndex:(NSUInteger)index {
    [self willChangeValueForKey:@"hasErrors"];
    ZKSObject *row = self.queryResult.records[index];
    row.errorMsg = errMsg;
    [self didChangeValueForKey:@"hasErrors"];
}

- (NSInteger)size {
    return [self.queryResult size];
}

- (BOOL)done {
    return [self.queryResult done];
}

- (NSString *)queryLocator {
    return [self.queryResult queryLocator];
}

- (NSArray *)records {
    return [self.queryResult records];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)v {
    return [self.queryResult numberOfRowsInTableView:v];
}

- (id)tableView:(NSTableView *)view objectValueForTableColumn:(NSTableColumn *)tc row:(NSInteger)rowIdx {
    return [self columnValue:tc.identifier atRow:rowIdx];
}

- (BOOL)allowEdit:(NSTableColumn *)aColumn {
    if (!self.editable) return NO;
    if (self.delegate.isEditing) return NO;
    if ([aColumn.identifier isEqualToString:ERROR_COLUMN_IDENTIFIER]) return NO;
    return [aColumn.identifier rangeOfString:@"."].location == NSNotFound;
}

- (BOOL)control:(NSControl *)control textShouldBeginEditing:(NSText *)fieldEditor {
    NSTableView *t = (NSTableView *)control;
    NSTableColumn *c = t.tableColumns[t.editedColumn];
    return [self allowEdit:c];
}

- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor {
    return YES;
}

- (void)tableView:(NSTableView *)tableView didClickTableColumn:(NSTableColumn *)tableColumn {
    if ([tableColumn.identifier isEqualToString:DELETE_COLUMN_IDENTIFIER]) {
        [self setChecksOnAllRows:![self hasCheckedRows]];
        [tableView reloadData];
    }
}

- (void)tableView:(NSTableView *)aTableView
    setObjectValue:(id)anObject
    forTableColumn:(NSTableColumn *)aTableColumn
    row:(NSInteger)rowIndex
{
    BOOL allow = [self allowEdit:aTableColumn];
    if (!allow) return;
    if ([aTableColumn.identifier isEqualToString:@"Id"]) 
        return;    // Id column is not really editable

    ZKSObject *row = self.queryResult.records[rowIndex];
    BOOL isDelete = [aTableColumn.identifier isEqualToString:DELETE_COLUMN_IDENTIFIER];
    if (isDelete) {
        [self setChecked:!row.checked onRowWithIndex:rowIndex];
    } else {
        if (self.delegate != nil && [self.delegate respondsToSelector:@selector(dataChangedOnObject:field:value:)]) {
            [self.delegate dataChangedOnObject:row field:aTableColumn.identifier value:anObject];
        }
    }
}

- (NSCell *)tableView:(NSTableView *)tableView dataCellForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (tableColumn == nil) return nil;
    id v = [self columnValue:tableColumn.identifier atRow:row];
    if ([v isKindOfClass:[ZKQueryResult class]])
        return imageCell;
    return [tableColumn dataCellForRow:row];
}

- (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray<NSSortDescriptor *> *)oldDescriptors {
    ZKQueryResult *qr = self.queryResult;
    NSArray *sorted = [qr.records sortedArrayUsingDescriptors:tableView.sortDescriptors];
    ZKQueryResult *r = [[ZKQueryResult alloc] initWithRecords:sorted size:qr.size done:qr.done queryLocator:qr.queryLocator];
    self.queryResult = r;
    [tableView reloadData];
}

-(id)columnValue:(NSString *)col atRow:(NSUInteger)rowIndex {
    NSArray *records = self.queryResult.records;
    if (rowIndex >= records.count) {
        return nil;
    }
    ZKSObject *row = records[rowIndex];
    if ([col isEqualToString:DELETE_COLUMN_IDENTIFIER]) {
        return @(row.checked);
    }
    if ([col isEqualToString:ERROR_COLUMN_IDENTIFIER]) {
        return row.errorMsg;
    }
    if ([col isEqualToString:TYPE_COLUMN_IDENTIFIER]) {
        return row.type;
    }
    NSArray *fieldPath = [col componentsSeparatedByString:@"."];
    NSObject *val = row;
    for (NSString *step in fieldPath) {
        if ([val isKindOfClass:[ZKSObject class]]) {
            val = [(ZKSObject *)val fieldValue:step];
        } else {
            val = [val valueForKey:step];
        }
    }
    return val;
}

@end
