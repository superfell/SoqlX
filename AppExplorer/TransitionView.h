//
//  TransitionView.h
//  AppExplorer
//
//  Created by Simon Fell on 11/15/06.
//  Copyright 2006 Simon Fell. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <QuartzCore/CIFilter.h>

@interface TransitionView : NSView {
	NSAnimation	 	*animation;
	CIFilter	 	*transitionFilter;
}

-(void)performAnimationStartingWith:(NSBitmapImageRep *)startBmp endingWith:(NSBitmapImageRep *)endBmp ripplePoint:(NSPoint)pt withDuration:(float)timeInSeconds;

// your subclass should implement these 2 instead of drawRect
-(void)drawBackground:(NSRect)rect;
-(void)drawForeground:(NSRect)rect;

@end
