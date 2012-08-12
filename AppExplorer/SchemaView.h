// Copyright (c) 2006,2012 Simon Fell
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

@property (retain) DescribeListDataSource *describesDataSource;

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
