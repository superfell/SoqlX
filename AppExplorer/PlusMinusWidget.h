//
//  PlusMinusWidget.h
//  AppExplorer
//
//  Created by Simon Fell on 11/15/06.
//  Copyright 2006 Simon Fell. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SchemaView;

typedef enum pmButtonState
{
	pmOutside,
	pmInside,
	pmDown
} pmButtonState;

typedef enum pmButtonStyle
{
	pmPlusButton,
	pmMinusButton
} pmButtonStyle;

@interface PlusMinusWidget : NSObject {
	SchemaView			*view;
	NSRect				rect;
	pmButtonState		state;
	pmButtonStyle		style;
	BOOL				visible;
	NSTrackingRectTag	tagRect;
	id					target;
	SEL					action;	
}

-(id)initWithFrame:(NSRect)frame view:(SchemaView *)v andStyle:(pmButtonStyle)s;
-(BOOL)visible;
-(void)setVisible:(BOOL)aValue;
-(NSPoint)origin;
-(void)setOrigin:(NSPoint)aPoint;
-(pmButtonState)state;
-(void)setTarget:(id)target andAction:(SEL)action;

-(void)resetTrackingRect;
-(void)drawRect:(NSRect)frame;
-(void)mouseDown:(NSEvent *)event;
-(void)mouseUp:(NSEvent *)event;
@end
