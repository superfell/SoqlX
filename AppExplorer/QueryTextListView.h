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

#import <Cocoa/Cocoa.h>

extern NSString *QueryTextListViewItem_Clicked;

@interface QueryTextListViewItem : NSView {
	NSString		*text;
	NSDictionary	*textAttributes;
	CGFloat			verticalPad;
	NSRect			textRect;
	NSColor			*backgroundColor;

	NSTrackingArea	*trackingArea;
	BOOL			highlighted;
}

-(id)initWithFrame:(NSRect)f attributes:(NSDictionary*)attributes;

@property (retain) NSString *text;
@property (retain) NSColor	*backgroundColor;

-(void)setFrameWidth:(CGFloat)w;
@end;

// This is a listview of items where each item is a string
// each item is managed by a QueryTextListViewItem
// upsertHead will handle the case where an existing item is "moved" to the head of the list.
@interface QueryTextListView : NSView {
	NSMutableArray	*items;
	NSDictionary	*textAttributes;
}

-(void)setInitialItems:(NSArray *)texts;
-(BOOL)upsertHead:(NSString *)text;
-(NSArray *)items;
@end
