// Copyright (c) 2008,2018 Simon Fell
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

#import "QueryResultCell.h"
#import "ZKQueryResult.h"

@implementation QueryResultCell

static NSImage *magnifyingGlassImage;
static NSDictionary *textAttrs;

+(void)initialize {
    // drawing the image with a factional alpha channel seems to be really slow, so we draw it once
    // at the alpha we want. Then use that output for our real drawing, which can then use an
    // alpha of 1.0, which isn't slow.
    NSImage *img = [NSImage imageNamed:NSImageNameRevealFreestandingTemplate];
    NSSize sz = img.size;
    NSImage *res = [[NSImage alloc] initWithSize:sz];
    [res lockFocus];
    [img drawInRect:NSMakeRect(0,0, sz.width, sz.height) fromRect:NSZeroRect operation:NSCompositeSourceOut fraction:0.6];
    [res unlockFocus];
    magnifyingGlassImage = res;
    textAttrs = @{NSFontAttributeName: [NSFont userFontOfSize:10.0]};
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    ZKQueryResult *qr = self.objectValue;
    if ([qr size] == 0) return;
    NSPoint cellPoint = cellFrame.origin;
    NSRect dstRect = NSMakeRect(cellPoint.x + 2,
                                cellPoint.y + ((cellFrame.size.height - magnifyingGlassImage.size.height) / 2),
                                magnifyingGlassImage.size.width,
                                magnifyingGlassImage.size.height);
    NSString *txt = [NSString stringWithFormat:@"%ld row%@", (long)qr.size, qr.size > 1 ? @"s" : @""];
    [controlView lockFocus];
    [magnifyingGlassImage drawInRect:dstRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1 respectFlipped:YES hints:nil];
    [txt drawAtPoint:NSMakePoint(cellPoint.x+20, cellPoint.y+1) withAttributes:textAttrs];
    [controlView unlockFocus];
}

@end
