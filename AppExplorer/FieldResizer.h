//
//  FieldResizer.h
//  AppExplorer
//
//  Created by Simon Fell on 3/24/09.
//  Copyright 2009 Simon Fell. All rights reserved.
//

#import <Cocoa/Cocoa.h>

//
// Can be used to resize a view/field when a splitter changes size
//
@interface FieldResizer : NSObject {
	IBOutlet	NSView		  *field;
	IBOutlet	NSSplitView	  *splitter;
}

@end
