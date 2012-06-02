//
//  EditableQueryResultWrapper.h
//  AppExplorer
//
//  Created by Simon Fell on 4/18/07.
//  Copyright 2007 Simon Fell. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ZKQueryResult.h"

NSString *DELETE_COLUMN_IDENTIFIER;
NSString *ERROR_COLUMN_IDENTIFIER;
NSArray  *ALL_APP_COLUMN_IDENTIFIERS;

@class ZKSObject;

@protocol EditableQueryResultWrapperDelegate
-(void) dataChangedOnObject:(ZKSObject *)sobject field:(NSString *)fieldName value:(id)value;
@end

@interface EditableQueryResultWrapper : NSObject {
	NSObject<EditableQueryResultWrapperDelegate>	*delegate;
	ZKQueryResult	*result;
	BOOL			editable;
	NSCell			*imageCell;
	NSMutableSet		*checkedRows;
	NSMutableDictionary *rowErrors;
}

- (id)initWithQueryResult:(ZKQueryResult *)qr;

- (ZKQueryResult *)queryResult;
- (void)setQueryResult:(ZKQueryResult *)newResults;

- (BOOL)editable;
- (void)setEditable:(BOOL)newAllowEdit;

- (NSObject<EditableQueryResultWrapperDelegate> *)delegate;
- (void)setDelegate:(NSObject<EditableQueryResultWrapperDelegate> *)aValue;

- (BOOL)hasCheckedRows;
- (int)numCheckedRows;
- (NSSet *)indexesOfCheckedRows;
- (void)setChecked:(BOOL)checked onRowWithIndex:(NSNumber *)index;

- (BOOL)hasErrors;
- (void)clearErrors;
- (void)addError:(NSString *)errMsg forRowIndex:(NSNumber *)index;

- (BOOL)allowEdit:(NSTableColumn *)aColumn;

// if you want to make inplace edits to the rows, then create a mutating context, make your changes, then finally call update.
- (id)createMutatingRowsContext;
- (void)remmoveRowAtIndex:(int)index context:(id)mutatingContext;
- (void)updateRowsFromContext:(id)context;

// pass through to QueryResult
- (int)size;
- (BOOL)done;
- (NSString *)queryLocator;
- (NSArray *)records;
// make it compaitble with the data source for a table
- (int)numberOfRowsInTableView:(NSTableView *)v;
- (id)tableView:(NSTableView *)view objectValueForTableColumn:(NSTableColumn *)tc row:(int)rowIdx;
@end

@interface EditableQueryResultWrapper (TableColumns)
-(NSArray *)allSystemColumnIdentifiers;
@end