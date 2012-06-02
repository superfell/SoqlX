//
//  BulkDelete.h
//  AppExplorer
//
//  Created by Simon Fell on 2/3/09.
//  Copyright 2009 Simon Fell. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class ProgressController;
@class QueryResultTable;
@class ZKSforceClient;

@interface BulkDelete : NSObject {
	ProgressController	*progress;
	NSOperationQueue	*queue;
	
	NSArray				*indexes;
	NSArray				*sfdcIds;
	NSMutableArray		*results;
	ZKSforceClient		*client;
	QueryResultTable	*table;
}

-(id)initWithClient:(ZKSforceClient *)client;
-(void)performBulkDelete:(QueryResultTable *)dataSource window:(NSWindow *)modelWindow;

@end
