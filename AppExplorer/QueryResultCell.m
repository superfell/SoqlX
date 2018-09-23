// Copyright (c) 2008 Simon Fell
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

@interface QueryResultCell ()
-(void)initProperties;
@end 

@implementation QueryResultCell

- (instancetype)initTextCell:(NSString *)txt {
    self = [super initTextCell:txt];
    [self initProperties];
    return self;
}


- (void)initProperties {
    myImage = [NSImage imageNamed:NSImageNameRevealFreestandingTemplate];
    myTextAttrs = @{NSFontAttributeName: [NSFont userFontOfSize:10.0]};
}

- (id)copyWithZone:(NSZone *)z {
    QueryResultCell *rhs = [super copyWithZone:z];
    [self initProperties];
    return rhs;
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    ZKQueryResult *qr = self.objectValue;
    if ([qr size] == 0) return;
    NSPoint cellPoint = cellFrame.origin;
    [controlView lockFocus];
    [myImage compositeToPoint:NSMakePoint(cellPoint.x+2, cellPoint.y+16) operation:NSCompositeSourceOver fraction:0.6];
    [[NSString stringWithFormat:@"%d row%@", [qr size], [qr size] > 1 ? @"s" : @""] drawAtPoint:NSMakePoint(cellPoint.x+20, cellPoint.y+1) withAttributes:myTextAttrs];
    [controlView unlockFocus];
}

@end
