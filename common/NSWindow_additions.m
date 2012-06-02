//
//  NSWindow_additions.m
//  AppExplorer
//
//  Created by Simon Fell on 3/24/09.
//  Copyright 2009 Simon Fell. All rights reserved.
//

#import "NSWindow_additions.h"


@implementation NSWindow (Fade)

-(IBAction)displayOrCloseWindow:(id)sender {
	if ([self alphaValue] > 0) {
		[[self animator] setAlphaValue:0.0];
		[self performSelector:@selector(close) withObject:nil afterDelay:[[NSAnimationContext currentContext] duration]];
	} else {
		[[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
		[self makeKeyAndOrderFront:self];
		[[self animator] setAlphaValue:1.0];
	}
}

@end
