// Copyright (c) 2006,2014 Simon Fell
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

#import <Cocoa/Cocoa.h>
#import "SObjectViewMode.h"
#import "IconProvider.h"

@class ZKDescribeSObject;
@class SchemaView;
@class PlusMinusWidget;

@interface SObjectBox : NSObject {
    SchemaView            *view;
    ZKDescribeSObject    *sobject;
    SObjectBoxViewMode    viewMode;
    NSMutableDictionary *titleAttributes;
    NSDictionary        *fieldAttributes;
    NSArray                *fieldsToDisplay;
    NSDictionary        *fieldRects;
    NSColor             *borderColor;
    NSColor                *gradientStartColor;
    NSColor             *gradientEndColor;
    NSTrackingRectTag    tagMainRect;
    NSSize                size;
    NSPoint                origin;
    BOOL                highlight;
    PlusMinusWidget        *plusWidget;
    PlusMinusWidget        *minusWidget;
    
    ZKDescribeSObject       *includeFksTo;
    NSObject<IconProvider>  *iconProvider;
}

-(instancetype)initWithFrame:(NSRect)frame andView:(SchemaView *)v NS_DESIGNATED_INITIALIZER;

@property (strong) ZKDescribeSObject *sobject;
@property (assign) SObjectBoxViewMode viewMode;
@property (strong) NSColor *color;
@property (strong) ZKDescribeSObject *includeFksTo;
@property (strong) NSObject<IconProvider> *iconProvider;

@property (getter=isHighlighted, readonly) BOOL highlighted;
@property (readonly) NSSize size;
@property (readonly) NSPoint centerPoint;

@property (assign) NSPoint origin;

-(void)resetTrackingRect;

-(void)drawRect:(NSRect)rect;
-(void)mouseDown:(NSEvent *)event;
-(void)mouseUp:(NSEvent *)event;
@property (readonly, copy) NSArray *fieldsToDisplay;
-(NSRect)rectOfFieldPaddedToEdges:(NSString *)fieldName;

@end
