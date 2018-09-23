// Copyright (c) 2008,2012 Simon Fell
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

#import "QueryTextListView.h"

static const CGFloat MARGIN = 5.0;

@implementation QueryTextListViewItem

-(instancetype)initWithFrame:(NSRect)f attributes:(NSDictionary*)attributes listView:(QueryTextListView *)lv {
    self = [super initWithFrame:f];
    listView = lv;  // not retained, to prevent retain loop.
    textAttributes = attributes;
    verticalPad = [@"M" sizeWithAttributes:textAttributes].height / 2; 
    backgroundColor = [NSColor whiteColor];
    trackingArea = [[NSTrackingArea alloc] initWithRect:f options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect owner:self userInfo:nil];
    [self addTrackingArea:trackingArea];
    [self setWantsLayer:YES];
    return self;
}

-(void)dealloc {
    [self removeTrackingArea:trackingArea];
}

- (void)recalcLayout:(CGFloat)width {
    NSRect p = NSMakeRect(MARGIN, verticalPad, width - (MARGIN*2), 0);
    NSSize txtSize = [text boundingRectWithSize:p.size options:NSStringDrawingUsesLineFragmentOrigin attributes:textAttributes].size;
    textRect = NSMakeRect(MARGIN, verticalPad, txtSize.width, txtSize.height);
    [self setFrameSize:NSMakeSize(width, textRect.size.height + verticalPad *2)];
}

- (void)recalcLayout {
    NSRect b = self.bounds;
    [self recalcLayout:b.size.width];
}

- (NSString *)text {
    return text;
}

- (void)setText:(NSString *)t {
    text = t;
    [self recalcLayout];
    [self setNeedsDisplay:YES];
}

-(void)setFrameWidth:(CGFloat)w {
    [self recalcLayout:w];
    [self setNeedsDisplay:YES];
}

- (NSColor *)backgroundColor {
    return backgroundColor;
}

- (void)setBackgroundColor:(NSColor *)c {
    if (c == backgroundColor) return;
    backgroundColor = c;
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)rect {
    NSRect b = self.bounds;
    NSColor *bg = highlighted ? [NSColor selectedControlColor] : backgroundColor;
    [bg set];
    NSRectFill(b);
    [text drawWithRect:textRect options:NSStringDrawingUsesLineFragmentOrigin attributes:textAttributes];
    [[NSColor grayColor] set];
    NSRectFill(NSMakeRect(b.origin.x, NSMaxY(b)-1, b.size.width, 1));
}

- (void)mouseEntered:(NSEvent *)theEvent {
    highlighted = YES;
    [self setNeedsDisplay:YES];
}

- (void)mouseExited:(NSEvent *)theEvent {
    highlighted = NO;
    [self setNeedsDisplay:YES];
}

- (void)mouseUp:(NSEvent *)theEvent {
    [listView.delegate queryTextListView:listView itemClicked:self];
}

- (BOOL)isFlipped {
    return YES;
}

- (BOOL)isOpaque {
    return YES;
}

@end

@interface QueryTextListView ()
-(QueryTextListViewItem *)createItem:(NSString *)text;
@end

@implementation QueryTextListView

@synthesize delegate;

-(instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
        textAttributes =  [NSMutableDictionary dictionaryWithObjectsAndKeys:
                            [NSFont titleBarFontOfSize:11.0], NSFontAttributeName,
                            [[NSColor blueColor] shadowWithLevel:0.33], NSForegroundColorAttributeName,
                            nil];
        items = [NSMutableArray arrayWithCapacity:10];
    }
    return self;
}


- (BOOL)isFlipped {
    return YES;
}

- (NSArray *)items {
    return items;
}

-(void)layoutChildren:(CGFloat)width {
    QueryTextListViewItem *p = nil;
    NSArray *colors = [NSColor controlAlternatingRowBackgroundColors];
    int idx = 0;
    for (QueryTextListViewItem *i in items) {
        [[i animator] setFrameOrigin:NSMakePoint(0, p == nil ? 0 : NSMaxY(p.frame))];
        [i animator].backgroundColor = colors[idx];
        [i setFrameWidth:width];
        p = i;
        idx ^=1;
    }
    [super setFrameSize:NSMakeSize(width, NSMaxY(p.frame))];
}

-(void)setFrameSize:(NSSize)s {
    [self layoutChildren:s.width];
}

-(BOOL)upsertHead:(NSString *)text {
    if ((items.count > 0) && ([text isEqualToString:[items[0] text]])) 
        return FALSE;

    int idx = 0;
    BOOL found = NO;
    for(QueryTextListViewItem *i in items) {
        if ([text isEqualToString:i.text]) {
            // move an existing item to the top of the list.
            [items removeObjectAtIndex:idx];
            [items insertObject:i atIndex:0];
            found = YES;
            break;
        }
        ++idx;
    }
    if (!found) {
        // create and insert a new item at the top of hte list
        QueryTextListViewItem *i = [self createItem:text];
        [items insertObject:i atIndex:0];
        // remove the oldest item if needed
        if (items.count > 10) {
            QueryTextListViewItem *toremove = items.lastObject;
            [items removeLastObject];
            [toremove removeFromSuperview];
        }
    }
    [self layoutChildren:self.bounds.size.width];
    return TRUE;
}

-(QueryTextListViewItem *)createItem:(NSString *)text {
    NSRect b = self.bounds;
    QueryTextListViewItem *i = [[QueryTextListViewItem alloc] initWithFrame:b attributes:textAttributes listView:self];
    i.text = text;
    [self addSubview:i];
    return i;
}

-(void)setInitialItems:(NSArray *)texts {
    for (NSString *text in texts) 
        [items addObject:[self createItem:text]];
    [self layoutChildren:self.bounds.size.width];
}

- (void)drawRect:(NSRect)rect {
}


@end
