//
//  SchemaView.h
//  AppExplorer
//
//  Created by Simon Fell on 11/5/06.
//  Copyright 2006 Simon Fell. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "TransitionView.h"

@class ZKDescribeSObject;
@class SObjectBox;
@class DescribeListDataSource;
@class Explorer;

@interface SchemaView : TransitionView {
	SObjectBox				*centralBox;
	DescribeListDataSource  *describes;
	NSMutableDictionary		*relatedBoxes;	// (SObjectBox keyed by SObject name)
	NSArray					*foreignKeys;	// (of SObject box)
	NSArray					*children;		// (of SObject box)
	
	NSColor					*primaryColor;
	NSColor					*foreignKeyColor;
	NSColor					*childRelColor;
	BOOL					needsFullRedraw;
	BOOL					isPrinting;
	IBOutlet Explorer		*primaryController;
}

- (DescribeListDataSource *)describesDataSource;
- (void)setDescribesDataSource:(DescribeListDataSource *)newDataSource;
- (ZKDescribeSObject *)centralSObject;
- (void)setCentralSObject:(ZKDescribeSObject *)s;
- (void)setCentralSObject:(ZKDescribeSObject *)s withRipplePoint:(NSPoint)ripple;
- (SObjectBox *)centralBox;

- (void)layoutBoxes;
- (BOOL)mousePointerIsInsideRect:(NSRect)rect;
- (NSTrackingRectTag)addTrackingRect:(NSRect)rect owner:(id)owner;
- (BOOL)needsFullRedraw;
- (void)setNeedsFullRedraw:(BOOL)aValue;
@end
