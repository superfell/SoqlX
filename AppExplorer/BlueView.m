//
//  BlueView.m
//  AppExplorer
//
//  Created by Simon Fell on 3/10/09.
//  Copyright 2009 Simon Fell. All rights reserved.
//

#import "BlueView.h"


@implementation BlueView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    return self;
}

- (void)drawRect:(NSRect)rect {
	[[NSColor colorWithCalibratedRed:214.0f/256 green:221.0f/256 blue:229.0f/256 alpha:1.0] setFill];
	NSRectFill(rect);
}

-(BOOL)isOpaque {
	return YES;
}

@end
