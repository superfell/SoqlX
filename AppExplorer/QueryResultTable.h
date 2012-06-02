//
//  QueryResultTable.h
//  AppExplorer
//
//  Created by Simon Fell on 1/22/08.
//  Copyright 2008 Simon Fell. All rights reserved.
//
// This class wraps a QueryResult/EditableQueryResultsWrapper/NSTableView trifecta
//

#import <Cocoa/Cocoa.h>

@class ZKQueryResult;
@class EditableQueryResultWrapper;

@interface QueryResultTable : NSObject {
	id							delegate;
	NSTableView					*table;
	ZKQueryResult				*queryResult;
	EditableQueryResultWrapper	*wrapper;
}

- (id)initForTableView:(NSTableView *)view;

- (void)removeRowAtIndex:(int)row;

@property (readonly) NSTableView *table;
@property (readonly) EditableQueryResultWrapper *wrapper;
@property (retain) ZKQueryResult *queryResult;
@property (assign) id delegate;

-(BOOL)hasCheckedRows;
-(void)showHideErrorColumn;
-(void)replaceQueryResult:(ZKQueryResult *)queryResult;	// this is like setQR, except it doesn't reset everything
@end
