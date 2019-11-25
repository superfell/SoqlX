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
#import <ZKSforce/ZKQueryResult.h>

@implementation QueryResultCell

static NSImage *magnifyingGlassImage;
static NSButtonCell *magnifyingGlassCell;
static NSDictionary *textAttrs;


+(void)initialize {
    magnifyingGlassImage = [NSImage imageNamed:NSImageNameRevealFreestandingTemplate];
    magnifyingGlassCell = [[NSButtonCell alloc] initImageCell:magnifyingGlassImage];
    magnifyingGlassCell.bezeled = NO;
    magnifyingGlassCell.bordered = NO;
    textAttrs = @{NSFontAttributeName: [NSFont userFontOfSize:10.0],
                  NSForegroundColorAttributeName: [NSColor textColor] };
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
    [magnifyingGlassCell drawInteriorWithFrame:dstRect inView:controlView];
    [txt drawAtPoint:NSMakePoint(cellPoint.x+20, cellPoint.y+1) withAttributes:textAttrs];
}

@end
