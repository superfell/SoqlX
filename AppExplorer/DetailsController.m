//
//  DetailsController.m
//  AppExplorer
//
//  Created by Simon Fell on 1/21/07.
//  Copyright 2007 Simon Fell. All rights reserved.
//

#import "DetailsController.h"
#import "../common/NSWindow_additions.h"

@implementation DetailsController

+(void)initialize {
	[self setKeys:[NSArray arrayWithObject:@"dataSource"] triggerChangeNotificationsForDependentKey:@"title"];
}

-(void)awakeFromNib {
	[window setAlphaValue:0.0];
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"details"])
		[self updateDetailsState:self];
}

-(IBAction)updateDetailsState:(id)sender {
	[window displayOrCloseWindow:sender];
}

-(NSString *)title {
	if ([self dataSource] == nil) return @"Details";
	return [[self dataSource] description];
}

-(NSObject *)dataSource {
	return [detailsTable dataSource];
}

-(void)setDataSource:(NSObject *)aValue {
	NSObject *oldDataSource = [self dataSource];
	[detailsTable setDataSource:aValue];
	[aValue retain];
	[oldDataSource release];
}

-(void)windowWillClose:(NSNotification *)notification {
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"details"];
	[[window animator] setAlphaValue:0.0];
}

@end
