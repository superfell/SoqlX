// Copyright (c) 2007 Simon Fell
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

NSString *DELETE_COLUMN_IDENTIFIER = @"row__delete";
NSString *ERROR_COLUMN_IDENTIFIER = @"row__error";

@interface EQRWMutating : NSObject {
	NSMutableArray *rows;
	NSMutableArray *checkMarks;
	NSMutableArray *errors;
}
-(id)initWithRows:(NSArray *)rows errors:(NSDictionary *)errors checkMarks:(NSSet *)checks;
-(void)removeRowAtIndex:(int)index;
-(NSArray *)rows;
-(NSArray *)checkMarks;
-(NSArray *)errors;
@end

@implementation EQRWMutating 

-(id)initWithRows:(NSArray *)r errors:(NSDictionary *)err checkMarks:(NSSet *)checks {
	self = [super init];
	rows = [[NSMutableArray arrayWithArray:r] retain];
	checkMarks = [[NSMutableArray arrayWithCapacity:[rows count]] retain];
	errors = [[NSMutableArray arrayWithCapacity:[rows count]] retain];
	for (int i =0; i < [rows count]; i++) {
		[checkMarks addObject:[NSNumber numberWithBool:FALSE]];
		[errors addObject:[NSNull null]];
	}
	for (NSNumber *n in checks) 
		[checkMarks replaceObjectAtIndex:[n intValue] withObject:[NSNumber numberWithBool:TRUE]];
	
	for (NSNumber *n in [err allKeys])
		[errors replaceObjectAtIndex:[n intValue] withObject:[err objectForKey:n]];
	return self;
}

-(void)dealloc {
	[rows release];
	[checkMarks release];
	[errors release];
	[super dealloc];
}

-(void)removeRowAtIndex:(int)index {
	[rows removeObjectAtIndex:index];
	[checkMarks removeObjectAtIndex:index];
	[errors removeObjectAtIndex:index];
}

-(NSArray *)rows {
	return rows;
}

-(NSArray *)checkMarks {
	return checkMarks;
}

-(NSArray *)errors {
	return errors;
}

@end

@implementation EditableQueryResultWrapper

- (id)initWithQueryResult:(ZKQueryResult *)qr {
	self = [super init];
	result = [qr retain];
	editable = NO;
	imageCell = [[QueryResultCell alloc] initTextCell:@""];
	checkedRows = [[NSMutableSet alloc] init];
	rowErrors = [[NSMutableDictionary alloc] init];
	return self;
}

- (void)dealloc {
	[result release];
	[imageCell release];
	[checkedRows release];
	[rowErrors release];
	[super dealloc];
}

- (id)createMutatingRowsContext {
	EQRWMutating *c = [[EQRWMutating alloc] initWithRows:[result records] errors:rowErrors checkMarks:checkedRows];
	return [c autorelease];
}

- (void)remmoveRowAtIndex:(int)index context:(id)mutatingContext {
	[(EQRWMutating *)mutatingContext removeRowAtIndex:index];
}

- (void)updateRowsFromContext:(id)context {
	EQRWMutating *ctx = (EQRWMutating *)context;
	NSArray *rows = [ctx rows];
	[self clearErrors];
	int r = 0;
	for (id err in [ctx errors]) {
		if (err != [NSNull null])
			[self addError:(NSString *)err forRowIndex:[NSNumber numberWithInt:r]];
		++r;
	}
	r = 0;
	[self willChangeValueForKey:@"hasCheckedRows"];
	[checkedRows removeAllObjects];
	for (NSNumber *c in [ctx checkMarks]) {
		if ([c boolValue]) 
			[checkedRows addObject:[NSNumber numberWithInt:r]];
		++r;
	}
	[self didChangeValueForKey:@"hasCheckedRows"];
	
	int rowCountDiff = [[result records] count] - [rows count];
	ZKQueryResult *nr = [[[ZKQueryResult alloc] initWithRecords:rows size:[result size] - rowCountDiff done:[result done] queryLocator:[result queryLocator]] autorelease];
	[self setQueryResult:nr];
}

-(NSArray *)allSystemColumnIdentifiers {
	return [NSArray arrayWithObjects:DELETE_COLUMN_IDENTIFIER, ERROR_COLUMN_IDENTIFIER, nil];
}

- (void)setQueryResult:(ZKQueryResult *)newResults {
	if (result == newResults) return;
	[result autorelease];
	result = [newResults retain];
}

- (ZKQueryResult *)queryResult {
	return result;
}

- (BOOL)editable {
	return editable;
}

- (void)setEditable:(BOOL)newAllowEdit {
	editable = newAllowEdit;
}

- (NSObject<EditableQueryResultWrapperDelegate> *)delegate {
	return delegate;
}

- (void)setDelegate:(NSObject<EditableQueryResultWrapperDelegate> *)aValue {
	delegate = aValue;
}

- (BOOL)hasCheckedRows {
	return [checkedRows count] > 0;
}

- (BOOL)hasErrors {
	return [rowErrors count] > 0;
}

- (void)clearErrors {
	[rowErrors removeAllObjects];
}

- (void)addError:(NSString *)errMsg forRowIndex:(NSNumber *)index {
	[rowErrors setObject:errMsg forKey:index];
}

- (int)size {
	return [result size];
}

- (BOOL)done {
	return [result done];
}

- (NSString *)queryLocator {
	return [result queryLocator];
}

- (NSArray *)records {
	return [result records];
}

- (int)numberOfRowsInTableView:(NSTableView *)v {
	return [result numberOfRowsInTableView:v];
}

- (id)tableView:(NSTableView *)view objectValueForTableColumn:(NSTableColumn *)tc row:(int)rowIdx {
	if ([[tc identifier] isEqualToString:DELETE_COLUMN_IDENTIFIER]) 
		return [NSNumber numberWithBool:[checkedRows containsObject:[NSNumber numberWithInt:rowIdx]]];
	if ([[tc identifier] isEqualToString:ERROR_COLUMN_IDENTIFIER])
		return [rowErrors objectForKey:[NSNumber numberWithInt:rowIdx]];
	return [result tableView:view objectValueForTableColumn:tc row:rowIdx];
}

- (BOOL)allowEdit:(NSTableColumn *)aColumn {
	if (!editable) return NO;
	if ([[aColumn identifier] isEqualToString:ERROR_COLUMN_IDENTIFIER]) return NO;
	return [[aColumn identifier] rangeOfString:@"."].location == NSNotFound;
}

- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
	return [self allowEdit:aTableColumn];
}

- (void)setChecksOnAllRows:(BOOL)checked {
	[self willChangeValueForKey:@"hasCheckedRows"];
	if (checked) {
		int rows = [[result records] count];
		for (int i = 0; i < rows; i++)
			[checkedRows addObject:[NSNumber numberWithInt:i]];
	} else {
		[checkedRows removeAllObjects];
	}
	[self didChangeValueForKey:@"hasCheckedRows"];
}

- (void)setChecked:(BOOL)checked onRowWithIndex:(NSNumber *)index {
	BOOL dcv = [checkedRows count] < 2;
	if (dcv) [self willChangeValueForKey:@"hasCheckedRows"];
	if (checked)
		[checkedRows addObject:index];
	else
		[checkedRows removeObject:index];
	if (dcv) [self didChangeValueForKey:@"hasCheckedRows"];
}

- (int)numCheckedRows {
	return [checkedRows count];
}

- (NSSet *)indexesOfCheckedRows {
	return checkedRows;
}

- (void)tableView:(NSTableView *)tableView didClickTableColumn:(NSTableColumn *)tableColumn {
	if ([[tableColumn identifier] isEqualToString:DELETE_COLUMN_IDENTIFIER]) {
		[self setChecksOnAllRows:![self hasCheckedRows]];
		[tableView reloadData];
	}
}

- (void)tableView:(NSTableView *)aTableView
    setObjectValue:(id)anObject
    forTableColumn:(NSTableColumn *)aTableColumn
    row:(int)rowIndex
{
	BOOL allow = [self allowEdit:aTableColumn];
	if (!allow) return;
	if ([[aTableColumn identifier] isEqualToString:@"Id"]) 
		return;	// Id column is not really editable

	BOOL isDelete = [[aTableColumn identifier] isEqualToString:DELETE_COLUMN_IDENTIFIER];
	if (isDelete) {
		NSNumber *r = [NSNumber numberWithInt:rowIndex];
		BOOL currentState = [checkedRows containsObject:r];
		[self setChecked:!currentState onRowWithIndex:r]; 
	} else {
		if (delegate != nil && [delegate respondsToSelector:@selector(dataChangedOnObject:field:value:)]) {
			[delegate dataChangedOnObject:[[result records] objectAtIndex:rowIndex] field:[aTableColumn identifier] value:anObject];
		}
	}
}

- (NSCell *)tableView:(NSTableView *)tableView dataCellForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	if (tableColumn == nil) return nil;
	id v = [result tableView:tableView objectValueForTableColumn:tableColumn row:row];
	if ([v isKindOfClass:[ZKQueryResult class]]) 
		return imageCell;
	return [tableColumn dataCellForRow:row];
}

@end
