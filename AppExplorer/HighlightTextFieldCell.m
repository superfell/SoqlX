//
//  HighlightTextFieldCell.m
//  AppExplorer
//
//  Created by Simon Fell on 3/11/09.
//  Copyright 2009 Simon Fell. All rights reserved.
//

#import "HighlightTextFieldCell.h"


@implementation HighlightTextFieldCell

-(BOOL)zkStandout {
	return zkStandout;
}

-(void)setZkStandout:(BOOL)h {
	zkStandout = h;
}

-(void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
	NSRect tf = cellFrame;
	tf.origin.x += 5.0;
	tf.size.width -= 7.0;
	NSMutableDictionary *a = [NSMutableDictionary dictionary];
	[a setObject:[self font] forKey:NSFontAttributeName];
	[a setObject:[self textColor] forKey:NSForegroundColorAttributeName];
	NSString *v = [self stringValue];
	NSSize txtSize = [v sizeWithAttributes:a];

	if (zkStandout && ![self isHighlighted]) {
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
		[gradient drawInRect:[p bounds] angle:90];
		[nsContext restoreGraphicsState];
		[gradient release];
	
		[p stroke];
		tf = NSInsetRect(tf, 9, 0);
	}
	
	tf.origin.y += (NSHeight(tf) - txtSize.height) / 2;
	[[self stringValue] drawWithRect:tf options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingTruncatesLastVisibleLine attributes:a];
}

@end
