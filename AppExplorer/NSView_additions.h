//
//  NSView_additions.h
//  AppExplorer
//
//  Created by Simon Fell on 6/17/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSView (TrackingHelpers) 

- (BOOL)mousePointerIsInsideRect:(NSRect)rect;
- (NSTrackingRectTag)addTrackingRect:(NSRect)rect owner:(id)owner;

@end
