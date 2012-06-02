//
//  DataSources.h
//  AppExplorer
//
//  Created by Simon Fell on 9/4/06.
//  Copyright 2006 Simon Fell. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class ZKSforceClient;
@class ZKDescribeSObject;
@class ZKDescribeField;

@interface DescribeListDataSource : NSObject {
	NSArray					*types;
	NSDictionary			*descGlobalSobjects;
	ZKSforceClient			*sforce;
	NSMutableDictionary		*describes;
	NSMutableDictionary		*operations;
	NSOperationQueue		*describeQueue;
	
	NSString				*filter;
	NSArray					*filteredTypes;
	NSOutlineView			*outlineView;
}

- (void)setSforce:(ZKSforceClient *)sf;
- (void)setTypes:(NSArray *)t view:(NSOutlineView *)ov;

// access to the desc cache
- (ZKDescribeSObject *)describe:(NSString *)type;
- (BOOL)isTypeDescribable:(NSString *)type;
- (BOOL)hasDescribe:(NSString *)type;
- (void)prioritizeDescribe:(NSString *)type;

// filter the view
- (NSString *)filter;
- (void)setFilter:(NSString *)filterValue;

// for use in a table view
- (int)numberOfRowsInTableView:(NSTableView *)v;
- (id)tableView:(NSTableView *)view objectValueForTableColumn:(NSTableColumn *)tc row:(int)rowIdx;

// for use in an outline view
- (int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item;
- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item;
- (id)outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item;
- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item;

- (NSArray *)SObjects;
@end;


@interface SObjectDataSource : NSObject {
	ZKDescribeSObject	*sobject;
	NSArray				*titles;
}

- (id)initWithDescribe:(ZKDescribeSObject *)s;
// for use in a table view
- (int)numberOfRowsInTableView:(NSTableView *)v;
- (id)tableView:(NSTableView *)view objectValueForTableColumn:(NSTableColumn *)tc row:(int)rowIdx;

@end;

@interface SObjectFieldDataSource : NSObject {
	ZKDescribeField		*field;
	NSArray				*titles;
}
- (id)initWithDescribe:(ZKDescribeField *)f;
// for use in a table view
- (int)numberOfRowsInTableView:(NSTableView *)v;
- (id)tableView:(NSTableView *)view objectValueForTableColumn:(NSTableColumn *)tc row:(int)rowIdx;

@end;

@interface NoSelection : NSObject {
}
@end
