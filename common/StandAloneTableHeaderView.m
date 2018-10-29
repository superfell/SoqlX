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

#import "StandAloneTableHeaderView.h"

@interface StandAloneTableHeaderView()
@property (copy) NSDictionary *textAttributes;

@end

@implementation StandAloneTableHeaderView

@synthesize headerText, textAttributes;

-(instancetype)initWithFrame:(NSRect)rect {
    self = [super initWithFrame:rect];
    textAttributes = @{
                       NSFontAttributeName: [NSFont titleBarFontOfSize:11.0],
                       NSForegroundColorAttributeName : [NSColor headerTextColor],
                       };
    return self;
}


-(void)drawRect:(NSRect)rect {
    NSRect b = self.bounds;
    [[NSColor gridColor] set];
    NSRectFill(b);
    // TODO: need a light / < 10.14 color for this
    [[NSColor colorWithRed:0.17 green:0.18 blue:0.19 alpha:1.0] set];
    NSRect c = NSInsetRect(b,1,1);
    NSRectFill(c);
    NSSize txtSize = [headerText sizeWithAttributes:textAttributes];
    NSPoint txtPoint =NSMakePoint(c.origin.x + 9, (b.size.height - txtSize.height) / 2);
    [headerText drawAtPoint:txtPoint withAttributes:textAttributes];
}

@end
