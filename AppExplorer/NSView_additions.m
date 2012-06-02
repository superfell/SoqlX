//
//  NSView_additions.m
//  AppExplorer
//
//  Created by Simon Fell on 6/17/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "NSView_additions.h"


@implementation NSView (TrackingHelpers)


- (BOOL)mousePointerIsInsideRect:(NSRect)rect {
	NSPoint loc = [self convertPoint:[[self window] mouseLocationOutsideOfEventStream] fromView:nil];
	return NSPointInRect(loc, rect);
}

// addTrackingRect helper that calculates whether we're inside the rect or not
- (NSTrackingRectTag)addTrackingRect:(NSRect)rect owner:(id)owner {
	return [self addTrackingRect:rect owner:owner userData:nil assumeInside:[self mousePointerIsInsideRect:rect]];
}

@end
