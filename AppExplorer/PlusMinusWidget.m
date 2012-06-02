//
//  PlusMinusWidget.m
//  AppExplorer
//
//  Created by Simon Fell on 11/15/06.
//  Copyright 2006 Simon Fell. All rights reserved.
//

#import "PlusMinusWidget.h"
#import "SchemaView.h"

@interface PlusMinusWidget (Private)
-(void)clearTrackingRect;
-(void)setTrackingRect;
-(void)setState:(pmButtonState)newState;
@end

@implementation PlusMinusWidget

- (id)initWithFrame:(NSRect)frame view:(SchemaView *)v andStyle:(pmButtonStyle)s {
	self = [super init];
	view = [v retain];
	rect = frame;
	style = s;
	visible = YES;
	[self setTrackingRect];
	return self;
}

-(void)dealloc {
	[self clearTrackingRect];
	[view release];
	[super dealloc];
}

- (BOOL)visible {
	return visible;
}

- (void)setVisible:(BOOL)aValue {
	visible = aValue;
}

-(NSPoint)origin {
	return rect.origin;
}

-(void)setOrigin:(NSPoint)aPoint {
	rect.origin = aPoint;
	[self resetTrackingRect];
}

-(pmButtonState)state {
	return state;
}

-(void)setState:(pmButtonState)newState {
	state = newState;
}

-(void)setTarget:(id)aTarget andAction:(SEL)anAction {
	// we explicity don't retain this to stop a ref counting loop.
	target = aTarget;
	action = anAction;
}

- (void)resetTrackingRect {
	[self clearTrackingRect];
	[self setTrackingRect];
}

-(void)clearTrackingRect {
	[view removeTrackingRect:tagRect];
	tagRect = 0;	
}

-(void)setTrackingRect {
	tagRect = [view addTrackingRect:rect owner:self];
	[self setState:[view mousePointerIsInsideRect:rect] ? pmInside : pmOutside];
}

-(void)mouseEntered:(NSEvent *)event {
	[self setState:pmInside];
}

-(void)mouseExited:(NSEvent *)event {
	[self setState:pmOutside];
}

-(void)mouseDown:(NSEvent *)event {
	[self setState:pmDown];
}

-(void)mouseUp:(NSEvent *)event {
	if (state != pmDown) return;
	[self setState:pmInside];
	[target performSelector:action];
}

-(void)drawRect:(NSRect)ignoreMe
{
	if (!visible) return;
	if (state != pmOutside)
		[[NSColor blackColor] set];
	else 
		[[NSColor whiteColor] set];
	NSFrameRect(rect);
	if (state == pmDown)
		[[NSColor blackColor] set];
	else
		[[NSColor whiteColor] set];
	NSRectFill(NSInsetRect(rect,2,rect.size.height/2-1));
	if (style == pmPlusButton) 
		NSRectFill(NSInsetRect(rect,rect.size.width/2-1,2));
}


@end
