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

#import <Cocoa/Cocoa.h>

@class QueryTextListViewItem;
@class QueryTextListView;

@protocol QueryTextListViewDelegate

// Called when the user clicks on an item in the list.
-(void)queryTextListView:(QueryTextListView *)listView itemClicked:(QueryTextListViewItem *)item;

@end

// This is a listview of items where each item is a string
// each item is managed by a QueryTextListViewItem
@interface QueryTextListView : NSView {
    NSMutableArray                  *items;
    NSDictionary                    *textAttributes;
    id<QueryTextListViewDelegate>   __unsafe_unretained delegate;
}

// set the list of items in the list, to this array of strings.
-(void)setInitialItems:(NSArray *)texts;

// add a new item at the head/top of the list, if needed, the oldest item will be removed
// if the item added to the head already exists in the list, it will be moved to the head
// if the item is already at the head of the list, then nothing happens.
// returns true if the list actually changed in some way.
-(BOOL)upsertHead:(NSString *)text;

// The current list of QueryTextListViewItems in the list view.
@property (readonly, copy) NSArray *items;

@property (unsafe_unretained, nonatomic) id<QueryTextListViewDelegate> delegate;

@end

// The view/container for a single item in the list.
@interface QueryTextListViewItem : NSView {
    NSString        *text;
    NSDictionary    *textAttributes;
    CGFloat            verticalPad;
    NSRect            textRect;
    NSColor            *backgroundColor;

    NSTrackingArea    *trackingArea;
    BOOL            highlighted;
    
    QueryTextListView *listView;
}

-(instancetype)initWithFrame:(NSRect)f attributes:(NSDictionary*)attributes listView:(QueryTextListView *)lv NS_DESIGNATED_INITIALIZER;

@property (strong) NSString *text;
@property (strong) NSColor    *backgroundColor;

-(void)setFrameWidth:(CGFloat)w;

@end;

