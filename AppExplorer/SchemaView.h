// Copyright (c) 2006,2012,2014 Simon Fell
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

@class ZKDescribeSObject;
@class SObjectBox;
@class DescribeListDataSource;
@class Explorer;

@interface SchemaView : NSView {
    SObjectBox                *centralBox;
    DescribeListDataSource  *describes;
    NSMutableDictionary        *relatedBoxes;    // (SObjectBox keyed by SObject name)
    NSArray                    *foreignKeys;     // (of SObject box)
    NSArray                    *children;        // (of SObject box)
    
    NSColor                    *primaryColor;
    NSColor                    *foreignKeyColor;
    NSColor                    *childRelColor;
    IBOutlet Explorer        *primaryController;
}

@property (strong) DescribeListDataSource *describesDataSource;

@property (strong) ZKDescribeSObject *centralSObject;
- (void)setCentralSObject:(ZKDescribeSObject *)s withRipplePoint:(NSPoint)ripple;
@property (readonly, strong) SObjectBox *centralBox;

@property (assign) BOOL isPrinting;

- (void)layoutBoxes;
- (BOOL)mousePointerIsInsideRect:(NSRect)rect;
- (NSTrackingRectTag)addTrackingRect:(NSRect)rect owner:(id)owner;
@end
