//
//  ProgressController.h
//  AppExplorer
//
//  Created by Simon Fell on 2/3/09.
//  Copyright 2009 Simon Fell. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface ProgressController : NSObject {
	IBOutlet	NSWindow	*window;
	NSString				*progressLabel;
	double					progressValue;
}

@property (copy) NSString *progressLabel;
@property (assign) double progressValue; 

-(NSWindow *)progressWindow;

@end
