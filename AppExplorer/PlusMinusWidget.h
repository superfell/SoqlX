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
    SchemaView            *view;
    NSRect                rect;
    pmButtonState        state;
    pmButtonStyle        style;
    BOOL                visible;
    NSTrackingRectTag    tagRect;
    id                    target;
    SEL                    action;    
}

-(instancetype)initWithFrame:(NSRect)frame view:(SchemaView *)v andStyle:(pmButtonStyle)s NS_DESIGNATED_INITIALIZER;

@property (assign) BOOL visible;
@property (assign) NSPoint origin;

@property (readonly) pmButtonState state;
-(void)setTarget:(id)target andAction:(SEL)action;

-(void)resetTrackingRect;
-(void)drawRect:(NSRect)frame;
-(void)mouseDown:(NSEvent *)event;
-(void)mouseUp:(NSEvent *)event;
@end
