//
//  TransitionView.m
//  AppExplorer
//
//  Created by Simon Fell on 11/15/06.
//  Copyright 2006 Simon Fell. All rights reserved.
//

#import "TransitionView.h"
#import <QuartzCore/CIVector.h>

@interface TransitionViewAnimation : NSAnimation {
}
@end

@implementation TransitionViewAnimation
- (void)setCurrentProgress:(NSAnimationProgress)progress {
    [super setCurrentProgress:progress];
    [[self delegate] display];
}
@end

@implementation TransitionView

// NSView
- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
		animation = nil;
		transitionFilter = [[CIFilter filterWithName:@"CIRippleTransition"] retain];
		[transitionFilter setDefaults];
    }
    return self;
}

- (void)dealloc {
	[animation release];
	[transitionFilter release];
	[super dealloc];
}

-(void)drawAnimation:(NSRect)rect {
	[transitionFilter setValue:[NSNumber numberWithFloat:[animation currentValue]] forKey:@"inputTime"];
	CIImage *out = [transitionFilter valueForKey:@"outputImage"];
	[out drawInRect:rect fromRect:rect operation:NSCompositeSourceOver fraction:1.0];
}

-(void)drawBackground:(NSRect)rect {	
}

-(void)drawForeground:(NSRect)rect {	
}

// NSView
- (void)drawRect:(NSRect)rect {
	[self drawBackground:rect];
	if (animation == nil)
		[self drawForeground:rect];
	else
		[self drawAnimation:rect];
}

- (CIImage *)inputShadingImage {
	NSBundle *bundle = [NSBundle mainBundle];
	NSData *shadingBitmapData = [NSData dataWithContentsOfFile:[bundle pathForResource:@"restrictedshine" ofType:@"tiff"]];
    NSBitmapImageRep *shadingBitmap = [[[NSBitmapImageRep alloc] initWithData:shadingBitmapData] autorelease];
    CIImage * image = [[[CIImage alloc] initWithBitmapImageRep:shadingBitmap] autorelease];
	return image;
}

// TransitionView
-(void)performAnimationStartingWith:(NSBitmapImageRep *)startBmp endingWith:(NSBitmapImageRep *)endBmp ripplePoint:(NSPoint)pt withDuration:(float)timeInSeconds {
	// setup the transition filter
	CIImage *start = [[CIImage alloc] initWithBitmapImageRep:startBmp];
	CIImage *end   = [[CIImage alloc] initWithBitmapImageRep:endBmp];
	[transitionFilter setValue:start forKey:@"inputImage"];
	[transitionFilter setValue:end   forKey:@"inputTargetImage"];
	NSRect v = [self visibleRect];
	CIVector *extent = [CIVector vectorWithX:v.origin.x Y:v.origin.y Z:v.size.width W:v.size.height];
	[transitionFilter setValue:extent forKey:@"inputExtent"];
	CIVector *center = [CIVector vectorWithX:pt.x Y:pt.y];
	[transitionFilter setValue:center forKey:@"inputCenter"];
	[transitionFilter setValue:[self inputShadingImage] forKey:@"inputShadingImage"];	
	
	// setup and run the animation
	animation = [[TransitionViewAnimation alloc] initWithDuration:timeInSeconds animationCurve:NSAnimationEaseInOut];
	[animation setDelegate:self];
	[animation startAnimation];

	// all done, cleanup
	[start release];
	[end release];
	[animation release];
	animation = nil;
	[self setNeedsDisplay:YES];
}

@end
