//
//  QueryTextListView.h
//  AppExplorer
//
//  Created by Simon Fell on 1/28/08.
//  Copyright 2008 Simon Fell. All rights reserved.
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


@interface QueryTextListView : NSView {
	NSMutableArray	*items;
	NSDictionary	*textAttributes;
}

-(void)setInitialItems:(NSArray *)texts;
-(BOOL)upsertHead:(NSString *)text;
-(NSArray *)items;
@end
