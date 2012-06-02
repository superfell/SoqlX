//
//  ProgressController.m
//  AppExplorer
//
//  Created by Simon Fell on 2/3/09.
//  Copyright 2009 Simon Fell. All rights reserved.
//

#import "ProgressController.h"


@implementation ProgressController

@synthesize progressLabel, progressValue;

+(void)initialize {
	[self setKeys:[NSArray arrayWithObject:@"progressValue"] triggerChangeNotificationsForDependentKey:@"progressAnimate"];
}

-(NSWindow *)progressWindow {
	if (window == nil) 
		[NSBundle loadNibNamed:@"ProgressWindow" owner:self];	
	return window;
}

-(void)dealloc {
	[progressLabel release];
	[window release];
	[super dealloc];
}

-(BOOL)progressAnimate {
	return progressValue > 0.0f;
}

@end
