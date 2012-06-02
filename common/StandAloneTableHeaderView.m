// Copyright (c) 2006 Simon Fell
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

#import "StandAloneTableHeaderView.h"

@implementation StandAloneTableHeaderView

-(id)initWithFrame:(NSRect)rect {
	[super initWithFrame:rect];
	textAttributes =  [[NSMutableDictionary dictionaryWithObjectsAndKeys:
						[NSFont titleBarFontOfSize:11.0], NSFontAttributeName,
						[NSColor blackColor], NSForegroundColorAttributeName,
						nil] retain];
						
	gradient = [[NSGradient alloc] initWithColors:[NSArray arrayWithObjects:[NSColor whiteColor], [NSColor colorWithCalibratedRed:0.875 green:0.875 blue:0.875 alpha:1.0], [NSColor whiteColor], nil]];
	return self;
}

-(void)dealloc {
	[headerText release];
	[textAttributes release];
	[gradient release];
	[super dealloc];
}

-(void)drawRect:(NSRect)rect {
	NSRect b = [self bounds];
	[[NSColor colorWithCalibratedRed:0.698 green:0.698 blue:0.698 alpha:1.0] set];
	NSRectFill(b);
	[gradient drawInRect:NSInsetRect(b,1,1) angle:90];
	NSRect txtRect = NSInsetRect(b, 5,1);
	[headerText drawInRect:txtRect withAttributes:textAttributes];
}

-(void)setHeaderText:(NSString *)newValue {
	if (newValue != headerText) {
		[headerText release];
		headerText = [newValue copy];
	}
}

-(NSString *)headerText {
	return [[headerText retain] autorelease];
}

@end
