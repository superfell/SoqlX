//
//  QueryListController.h
//  AppExplorer
//
//  Created by Simon Fell on 2/2/08.
//  Copyright 2008 Simon Fell. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class QueryTextListView;

@interface QueryListController : NSObject {
	IBOutlet QueryTextListView	*view;
	IBOutlet NSWindow			*window;
}

-(IBAction)showHideWindow:(id)sender;

-(void)addQuery:(NSString *)soql;

@end
