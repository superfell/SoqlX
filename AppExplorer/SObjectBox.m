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

#import "SObjectBox.h"
#import "SchemaView.h"
#import "zkDescribeSObject.h"
#import "FieldImportance.h"
#import "PlusMinusWidget.h"

static const float minimumWidth = 100.0;
static const float borderWidth = 2.0;
static const float radius = 8.0;
static const float gradientAngle = 235.0;
static const float plusMinusSize = 10.0;
static const float titleIconGap  = 6.0f;

@interface SObjectBox ()
-(void)updateColors;
-(void)recalcLayout;
-(void)recalcFieldsToDisplay;
-(void)drawFieldsToDisplay:(NSRect)rect;
-(void)clearTrackingRect;
-(void)setTrackingRect;
@property (readonly) float titleHeight;
@property (readonly) NSPoint positionForMinusWidget;
@property (readonly) NSPoint positionForPlusWidget;
-(void)positionPlusMinusWidgets;
@end

@implementation SObjectBox

@synthesize view=view;

-(instancetype)initWithFrame:(NSRect)frame andView:(SchemaView *)v {
    self = [super init];
    view = v;
    origin = frame.origin;
    size = frame.size;
    self.color = [NSColor orangeColor];
    // Set up text attributes for drawing
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    [paragraphStyle setParagraphStyle:[NSParagraphStyle defaultParagraphStyle]];
    paragraphStyle.alignment = NSTextAlignmentLeft;
    paragraphStyle.lineBreakMode = NSLineBreakByTruncatingTail;
    float fieldFontSize = ([NSFont systemFontSizeForControlSize:NSControlSizeSmall] + [NSFont systemFontSizeForControlSize:NSControlSizeMini]) / 2;
    fieldAttributes = @{ NSFontAttributeName:               [NSFont messageFontOfSize:fieldFontSize],
                         NSForegroundColorAttributeName:    [NSColor blackColor],
                         NSParagraphStyleAttributeName:     paragraphStyle};
    
    titleAttributes = @{ NSFontAttributeName:            [NSFont boldSystemFontOfSize:[NSFont systemFontSizeForControlSize:NSControlSizeSmall]],
                         NSForegroundColorAttributeName: [NSColor whiteColor],
                         NSParagraphStyleAttributeName:  paragraphStyle};
    highlight = NO;
    NSPoint ppos = [self positionForPlusWidget];
    NSPoint mpos = [self positionForMinusWidget];
    plusWidget = [[PlusMinusWidget alloc] initWithFrame:NSMakeRect(ppos.x, ppos.y, plusMinusSize, plusMinusSize) view:view andStyle:pmPlusButton];
    __weak SObjectBox *selfWeak = self;
    plusWidget.clickedBlock = ^() {
        selfWeak.viewMode = selfWeak.viewMode+1;
        [selfWeak.view layoutBoxes];
    };
    minusWidget = [[PlusMinusWidget alloc] initWithFrame:NSMakeRect(mpos.x, mpos.y, plusMinusSize, plusMinusSize) view:view andStyle:pmMinusButton];
    minusWidget.clickedBlock = ^() {
        selfWeak.viewMode = selfWeak.viewMode-1;
        [selfWeak.view layoutBoxes];
    };
    [self setTrackingRect];
    self.viewMode = vmImportantFields;
    return self;
}

- (void)dealloc {
    [self clearTrackingRect];
}

// SObjectBox
- (ZKDescribeSObject *)sobject {
    return sobject;
}

- (void)setSobject:(ZKDescribeSObject *)newSobject {
    if (newSobject == sobject) return;
    sobject = newSobject;
    [self recalcLayout];
}

-(NSObject<IconProvider> *)iconProvider {
    return iconProvider;
}

-(void)setIconProvider:(NSObject<IconProvider> *)ip {
    if (ip == iconProvider) return;
    BOOL needsLayout = ip != nil && iconProvider == nil;
    iconProvider = ip;
    if (needsLayout)
        [self recalcLayout];
}

-(ZKDescribeSObject *)includeFksTo {
    return includeFksTo;
}

-(void)setIncludeFksTo:(ZKDescribeSObject *)o {
    if (o == includeFksTo) return;
    includeFksTo = o;
    [self recalcLayout];
}

- (SObjectBoxViewMode)viewMode {
    return viewMode;
}



- (void)setViewMode:(SObjectBoxViewMode)newMode {
    if ((newMode < vmTitleOnly) || (newMode > vmAllFields)) return;
    if (viewMode == newMode) return;
    viewMode = newMode;
    plusWidget.visible = viewMode != vmAllFields;
    minusWidget.visible = viewMode != vmTitleOnly;
    [self recalcLayout];
}

- (NSColor *)color {
    return borderColor;
}

- (void)setColor:(NSColor *)newColor {
    if (newColor == borderColor) return;
    borderColor = newColor;
    [self updateColors];
}

- (void)updateColors {
    NSColor *c = highlight ? [borderColor highlightWithLevel:0.25] : borderColor;
    gradientStartColor = [c blendedColorWithFraction:0.4 ofColor:[NSColor whiteColor]];
    gradientEndColor   = [c blendedColorWithFraction:0.2 ofColor:[NSColor whiteColor]];
}

- (void)setOrigin:(NSPoint)point {
    origin = point;
    [self resetTrackingRect];
    [self positionPlusMinusWidgets];
    [view setNeedsDisplay:YES];
}

- (NSPoint)origin {
    return origin;
}

- (NSSize)size {
    return size;
}

- (NSPoint)centerPoint {
    return NSMakePoint(origin.x + size.width/2, origin.y + size.height/2);
}

- (NSRect)bounds {
    return NSMakeRect(origin.x, origin.y, size.width, size.height);
}

- (BOOL)isHighlighted {
    return highlight;
}

-(NSString *)title {
    return sobject == nil ? @"Select an SObject" : sobject.name;
}

- (NSArray *)fieldsToDisplay {
    return fieldsToDisplay;
}

- (NSRect)rectToDrawField:(NSString *)fieldName {
    NSValue *vRect = fieldRects[fieldName];
    if (vRect == nil) return NSZeroRect;
    return NSOffsetRect(vRect.rectValue, origin.x, origin.y);
}

- (NSRect)rectOfFieldPaddedToEdges:(NSString *)fieldName {
    NSRect r = [self rectToDrawField:fieldName];
    if (NSIsEmptyRect(r)) return r;
    return NSMakeRect(origin.x, r.origin.y, size.width, r.size.height);
}

-(float)titleHeight {
    NSSize sz = [[self title] sizeWithAttributes:titleAttributes];
    return sz.height;
}

-(NSPoint)positionForMinusWidget {
    NSPoint plus = [self positionForPlusWidget];
    return NSMakePoint(plus.x - plusMinusSize, plus.y);
}

-(NSPoint)positionForPlusWidget {
    NSRect frame = [self bounds];
    return NSMakePoint(NSMaxX(frame) - plusMinusSize - borderWidth*2, NSMaxY(frame) - [self titleHeight] - plusMinusSize - borderWidth*5);
}

-(void)positionPlusMinusWidgets {
    plusWidget.origin = [self positionForPlusWidget];
    minusWidget.origin = [self positionForMinusWidget];
}

- (void)recalcLayout {
    [self recalcFieldsToDisplay];
    NSMutableDictionary *positions = [NSMutableDictionary dictionary];
    NSSize titleTextSz = [[self title] sizeWithAttributes:titleAttributes];
    NSSize titleIconSz = [iconProvider iconForType:sobject.name].size;
    float iconPlusGap = titleIconSz.width > 0 ? titleIconSz.width + titleIconGap : 0;
    float newWidth = MAX(minimumWidth, titleTextSz.width + iconPlusGap + borderWidth*3);
    // borderWidth 3 in use, 2 for padding between edges
    float newHeight = borderWidth*2;
    for (ZKDescribeField *field in fieldsToDisplay) {
        NSSize fieldSz = [field.name sizeWithAttributes:fieldAttributes];
        newWidth = MAX(newWidth, fieldSz.width + borderWidth*4);
        NSRect fieldRect = NSMakeRect(borderWidth*2, newHeight, fieldSz.width, fieldSz.height);
        positions[field.name] = [NSValue valueWithRect:fieldRect];
        newHeight += fieldSz.height;
    }
    newHeight += titleTextSz.height + borderWidth *4;
    // recalc frame posn, leaving it centered where it used to be.
    origin.x -= (newWidth - size.width) /2;
    origin.y -= (newHeight - size.height) /2;
    size.width = newWidth;
    size.height = newHeight;
    fieldRects = positions;
    [self positionPlusMinusWidgets];
    [self resetTrackingRect];    
    [view setNeedsDisplay:YES];
}

-(BOOL)shouldDisplayField:(ZKDescribeField *)f {
    if ([f shouldDisplayInMode:viewMode]) return YES;
    if (includeFksTo == nil) return NO;
    if ([f.type caseInsensitiveCompare:@"reference"] != NSOrderedSame) return NO;
    return [f.referenceTo containsObject:includeFksTo.name];
}

-(void)recalcFieldsToDisplay {
    NSMutableArray *fields = [[NSMutableArray alloc] init];
    for (ZKDescribeField *f in sobject.fields) {
        if ([self shouldDisplayField:f])
            [fields addObject:f];
    }
    NSSortDescriptor *sortImportance = [[NSSortDescriptor alloc] initWithKey:@"importance" ascending:NO];
    NSSortDescriptor *sortName = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:NO];
    [fields sortUsingDescriptors:@[sortImportance, sortName]];
    fieldsToDisplay = fields;
}

-(void)drawFieldsToDisplay:(NSRect)rect {
    for (ZKDescribeField *field in fieldsToDisplay) 
        [field.name drawInRect:[self rectToDrawField:field.name] withAttributes:fieldAttributes];
}

- (NSBezierPath *)titlePathWithinRect:(NSRect)rect cornerRadius:(float)cRadius titleRect:(NSRect)titleRect {
    // Construct rounded rect path
    NSRect bgRect = rect;
    int minX = NSMinX(bgRect);
    int maxY = NSMaxY(bgRect);
    int minY = NSMinY(titleRect) - (maxY - (titleRect.origin.y + titleRect.size.height));
    
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path moveToPoint:NSMakePoint(minX, minY)];
    
    // Draw full titlebar, since we're either set to always do so, or we don't have room for a short one.
    [path lineToPoint:NSMakePoint(NSMaxX(bgRect), minY)];
    [path appendBezierPathWithArcFromPoint:NSMakePoint(NSMaxX(bgRect), maxY) 
                                       toPoint:NSMakePoint(NSMaxX(bgRect) - (bgRect.size.width / 2.0), maxY) 
                                       radius:radius];
    [path appendBezierPathWithArcFromPoint:NSMakePoint(minX, maxY) 
                                   toPoint:NSMakePoint(minX, minY) 
                                    radius:cRadius];
    [path closePath];
    return path;
}

-(void)drawBoxAndTitle:(NSRect)rect {
    // Construct rounded rect path
    NSRect boxRect = [self bounds];
    NSRect bgRect = NSInsetRect(boxRect, borderWidth / 2.0, borderWidth / 2.0);
    bgRect = NSIntegralRect(bgRect);
    bgRect.origin.x += 0.5;
    bgRect.origin.y += 0.5;

    NSBezierPath *bgPath = [NSBezierPath bezierPathWithRoundedRect:bgRect xRadius:radius yRadius:radius];
    
    // Draw gradient background
    NSGraphicsContext *nsContext = [NSGraphicsContext currentContext];
    [nsContext saveGraphicsState];
    [bgPath addClip];
    NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:gradientStartColor endingColor:gradientEndColor];
    NSRect gradientRect = bgPath.bounds;
    [gradient drawInRect:gradientRect angle:gradientAngle];
    [nsContext restoreGraphicsState];
    
    // Create drawing rectangle for title
    NSImage *titleIcon = [iconProvider iconForType:sobject.name];
    NSSize titleIconSize = titleIcon.size;
    float iconOffset = titleIcon == nil ? 0 : titleIconSize.width + titleIconGap;
    float titleHInset = borderWidth * 2;
    float titleVInset = borderWidth;
    NSString *title = [self title];
    NSSize titleSize = [title sizeWithAttributes:titleAttributes];
    NSRect titleRect = NSMakeRect(boxRect.origin.x + titleHInset + iconOffset,
                                  boxRect.origin.y + boxRect.size.height - titleSize.height - (titleVInset * 2.0), 
                                  titleSize.width + borderWidth, 
                                  titleSize.height);
    titleRect.size.width = MIN(titleRect.size.width, boxRect.size.width - (2.0 * titleHInset));
    [borderColor set];
    // Draw title background
    [[self titlePathWithinRect:bgRect cornerRadius:radius titleRect:titleRect] fill];
    // Draw rounded rect around entire box
    bgPath.lineWidth = borderWidth;
    [bgPath stroke];
    // Draw title text
    [title drawInRect:titleRect withAttributes:titleAttributes];
    // Draw title icon if we have one
    if (titleIcon != nil) {
        NSRect iconRect = titleRect;
        iconRect.origin.x -= iconOffset;
        iconRect.size.width = titleIconSize.width;
        [titleIcon drawInRect:iconRect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0 respectFlipped:YES hints:nil];
    }
}

- (void)drawRect:(NSRect)dirtyRect {
    NSRect b = [self bounds];
    // only do drawing if we're inside the dirtyBounds
    if (!NSIntersectsRect(b, dirtyRect)) return;
    [self drawBoxAndTitle:dirtyRect];
    [plusWidget drawRect:dirtyRect];
    [minusWidget drawRect:dirtyRect];
    [self drawFieldsToDisplay:dirtyRect];
}

- (void)resetTrackingRect {
    [self clearTrackingRect];
    [self setTrackingRect];
    [plusWidget resetTrackingRect];
    [minusWidget resetTrackingRect];
}

-(void)clearTrackingRect {
    [view removeTrackingRect:tagMainRect];
    tagMainRect = 0;    
}

-(void)setHighlight:(BOOL)newValue {
    if (highlight == newValue) return;
    highlight = newValue;
    [self updateColors];
    [view setNeedsDisplayInRect:[self bounds]];
}

-(void)setTrackingRect {
    NSRect rect = [self bounds];
    tagMainRect = [view addTrackingRect:rect owner:self];
    [self setHighlight:[view mousePointerIsInsideRect:rect]];
}

- (void)mouseEntered:(NSEvent *)event {
    [self setHighlight:YES];
}

- (void)mouseExited:(NSEvent *)event {
    [self setHighlight:NO];
}

-(void)mouseUp:(NSEvent *)event {
    if ([plusWidget state] == pmDown)
        [plusWidget mouseUp:event];
    else if ([minusWidget state] == pmDown)
        [minusWidget mouseUp:event];
}

-(void)mouseDown:(NSEvent *)event {
    if ([plusWidget state] == pmInside)
        [plusWidget mouseDown:event];
    else if ([minusWidget state] == pmInside)
        [minusWidget mouseDown:event];
    else if (event.clickCount == 2)
        [view setCentralSObject:sobject withRipplePoint:[self centerPoint]];
}

@end
