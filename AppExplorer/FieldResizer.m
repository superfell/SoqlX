//
//  FieldResizer.m
//  AppExplorer
//
//  Created by Simon Fell on 3/24/09.
//  Copyright 2009 Simon Fell. All rights reserved.
//

#import "FieldResizer.h"


@implementation FieldResizer

-(void)splitViewDidResizeSubviews:(NSNotification *)aNotification {
	double newWidth = [[[splitter subviews] objectAtIndex:0] frame].size.width;
	NSRect f = [field frame];
	f.size.width = newWidth - f.origin.x;
	[field setFrameSize:f.size];
}

@end
