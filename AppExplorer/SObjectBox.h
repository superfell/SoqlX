//
//  SObjectBox.h
//  AppExplorer
//
//  Created by Simon Fell on 11/6/06.
//  Copyright 2006 Simon Fell. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SObjectViewMode.h"

@class ZKDescribeSObject;
@class SchemaView;
@class PlusMinusWidget;

@interface SObjectBox : NSObject {
	SchemaView			*view;
	ZKDescribeSObject	*sobject;
	SObjectBoxViewMode	viewMode;
	NSMutableDictionary *titleAttributes;
	NSDictionary		*fieldAttributes;
	NSArray				*fieldsToDisplay;
	NSDictionary		*fieldRects;
    NSColor 			*borderColor;
    NSColor				*gradientStartColor;
    NSColor 			*gradientEndColor;
	NSTrackingRectTag	tagMainRect;
	NSSize				size;
	NSPoint				origin;
	BOOL				highlight;
	BOOL				needsDrawing;
	PlusMinusWidget		*plusWidget;
	PlusMinusWidget		*minusWidget;
	
	ZKDescribeSObject	*includeFksTo;
}

-(id)initWithFrame:(NSRect)frame andView:(SchemaView *)v;

-(ZKDescribeSObject *)sobject;
-(void)setSobject:(ZKDescribeSObject *)newSobject;
-(SObjectBoxViewMode)viewMode;
-(void)setViewMode:(SObjectBoxViewMode)newMode;
-(NSColor *)color;
-(void)setColor:(NSColor *)aValue;
-(ZKDescribeSObject *)includeFksTo;
-(void)setIncludeFksTo:(ZKDescribeSObject *)o;

-(BOOL)isHighlighted;
-(NSSize)size;
-(NSPoint)centerPoint;
-(NSPoint)origin;
-(void)setOrigin:(NSPoint)point;
-(BOOL)needsDrawing;
-(void)setNeedsDrawing:(BOOL)aValue;

-(void)resetTrackingRect;

-(void)drawRect:(NSRect)rect forceRedraw:(BOOL)force;
-(void)mouseDown:(NSEvent *)event;
-(void)mouseUp:(NSEvent *)event;
-(NSArray *)fieldsToDisplay;
-(NSRect)rectOfFieldPaddedToEdges:(NSString *)fieldName;

@end
