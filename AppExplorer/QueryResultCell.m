//
//  QueryResultCell.m
//  AppExplorer
//
//  Created by Simon Fell on 1/24/08.
//  Copyright 2008 Simon Fell. All rights reserved.
//

#import "QueryResultCell.h"
#import "ZKQueryResult.h"

@interface QueryResultCell ()
-(void)initProperties;
@end 

@implementation QueryResultCell

- (id)initTextCell:(NSString *)txt {
	self = [super initTextCell:txt];
	[self initProperties];
	return self;
}

- (void)dealloc {
	[myImage release];
	[myTextAttrs release];
	[super dealloc];
}

- (void)initProperties {
	myImage = [[NSImage imageNamed:NSImageNameRevealFreestandingTemplate] retain];
	myTextAttrs = [[NSDictionary dictionaryWithObjectsAndKeys:[NSFont userFontOfSize:10.0], NSFontAttributeName, nil] retain];
}

- (id)copyWithZone:(NSZone *)z {
	QueryResultCell *rhs = [super copyWithZone:z];
	[self initProperties];
	return rhs;
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
	ZKQueryResult *qr = [self objectValue];
	if ([qr size] == 0) return;
    NSPoint cellPoint = cellFrame.origin;
    [controlView lockFocus];
	[myImage compositeToPoint:NSMakePoint(cellPoint.x+2, cellPoint.y+16) operation:NSCompositeSourceOver fraction:0.6];
    [[NSString stringWithFormat:@"%d row%@", [qr size], [qr size] > 1 ? @"s" : @""] drawAtPoint:NSMakePoint(cellPoint.x+20, cellPoint.y+1) withAttributes:myTextAttrs];
    [controlView unlockFocus];
}

@end
