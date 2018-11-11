// Copyright (c) 2009,2013 Simon Fell
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

#import "HighlightTextFieldCell.h"


@implementation HighlightTextFieldCell

@synthesize zkTextXOffset, zkImage, zkStandout;

-(void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    NSRect tf = cellFrame;
    tf.origin.x += 5.0;
    tf.size.width -= 7.0;
    NSMutableDictionary *a = [NSMutableDictionary dictionary];
    if (self.font != nil)
        a[NSFontAttributeName] = self.font;
    if (self.textColor != nil)
        a[NSForegroundColorAttributeName] = self.textColor;
    
    NSString *v = self.stringValue;
    NSSize txtSize = [v sizeWithAttributes:a];

    NSRect imagef = tf;
    tf.origin.x += zkTextXOffset;
    tf.size.width -= zkTextXOffset;

    if (zkStandout && !self.highlighted) {
        [[NSColor lightGrayColor] setStroke];
        NSRect bg = NSMakeRect(tf.origin.x, tf.origin.y, txtSize.width + 18, fmin(txtSize.height+18, tf.size.height));
        NSBezierPath *p = [NSBezierPath bezierPathWithRoundedRect:bg xRadius:8 yRadius:8];
        
        // Draw gradient background
        NSGraphicsContext *nsContext = [NSGraphicsContext currentContext];
        [nsContext saveGraphicsState];
        [p addClip];
        NSColor *gStartColor = [[NSColor yellowColor] blendedColorWithFraction:0.1 ofColor:[NSColor whiteColor]];
        NSColor *gEndColor   = [[NSColor yellowColor] blendedColorWithFraction:0.6 ofColor:[NSColor whiteColor]];
        NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:gStartColor endingColor:gEndColor];
        [gradient drawInRect:p.bounds angle:90];
        [nsContext restoreGraphicsState];
    
        [p stroke];
        tf = NSInsetRect(tf, 9, 0);
    }
    
    if (zkImage != nil) {
        imagef.size = zkImage.size;
        [zkImage drawInRect:imagef fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0 respectFlipped:YES hints:nil];
    }
    tf.origin.y += (NSHeight(tf) - txtSize.height) / 2;
    [self.stringValue drawWithRect:tf options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingTruncatesLastVisibleLine attributes:a];
}

@end
