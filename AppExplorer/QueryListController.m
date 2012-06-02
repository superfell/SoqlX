//
//  QueryListController.m
//  AppExplorer
//
//  Created by Simon Fell on 2/2/08.
//  Copyright 2008 Simon Fell. All rights reserved.
//

#import "QueryListController.h"
#import "QueryTextListView.h"
#import "../common/NSWindow_additions.h"

@implementation QueryListController

-(void)awakeFromNib {
	[window setContentBorderThickness:28.0 forEdge:NSMinYEdge]; 
	NSArray *saved = [[NSUserDefaults standardUserDefaults] arrayForKey:@"recentQueries"];
	if (saved != nil) 
		[view setInitialItems:saved];
	[window setAlphaValue:0.0];
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"recentQueriesVisible"])
		[self showHideWindow:self];
}

-(IBAction)showHideWindow:(id)sender {
	[window displayOrCloseWindow:sender];
}

- (void)addQuery:(NSString *)soql {
	soql = [soql stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if ([view upsertHead:soql]) {
		NSMutableArray *q = [NSMutableArray arrayWithCapacity:[[view items] count]];
		for (QueryTextListViewItem *i in [view items]) 
			[q addObject:[i text]];
			
		[[NSUserDefaults standardUserDefaults] setObject:q forKey:@"recentQueries"];
	}
}

-(void)windowWillClose:(NSNotification *)notification {
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"recentQueriesVisible"];
	[[window animator] setAlphaValue:0.0];
}

@end
