// Copyright (c) 2006 Simon Fell
//
// Permission is hereby granted, free of charge, to any person obtaining a 
// copy of this software and associated documentation files (the "Software"), 
// to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense, 
// and/or sell copies of the Software, and to permit persons to whom the 
// Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included 
// in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS 
// OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN 
// THE SOFTWARE.
//

#import "TransitionView.h"
#import <QuartzCore/CIVector.h>

@interface TransitionViewAnimation : NSAnimation {
}
@end

@implementation TransitionViewAnimation
- (void)setCurrentProgress:(NSAnimationProgress)progress {
    [super setCurrentProgress:progress];
    [(NSView *)[self delegate] display];
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
