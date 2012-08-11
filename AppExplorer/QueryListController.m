// Copyright (c) 2008,2012 Simon Fell
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

#import "QueryListController.h"
#import "QueryTextListView.h"
#import "NSWindow_additions.h"

static NSString *RECENT_QUERIES = @"recentQueries";
static NSString *RECENT_SHOWN = @"recentQueriesVisible";

@implementation QueryListController

-(void)awakeFromNib {
	[window setContentBorderThickness:28.0 forEdge:NSMinYEdge];
	[window setAlphaValue:0.0];
    visible = NO;
}

// returns TRUE if the visible state changes.
-(BOOL)updateWindowVisibleState:(BOOL)newState triggerKVONotification:(BOOL)doKvo {
    if (newState == visible) return FALSE;
    if (doKvo) [self willChangeValueForKey:@"windowVisible"];
    visible = newState;
    if (doKvo) [self didChangeValueForKey:@"windowVisible"];
    [[NSUserDefaults standardUserDefaults] setBool:visible forKey:[self prefName:RECENT_SHOWN]];
    return TRUE;
}

-(void)setWindowVisible:(BOOL)newState {
    // we don't need to manually trigger KVO here because this is the actual real property
    if ([self updateWindowVisibleState:newState triggerKVONotification:NO])
        [window displayOrCloseWindow:self];
}

-(BOOL)windowVisible {
    return visible;
}

- (void)addQuery:(NSString *)soql {
	soql = [soql stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if ([view upsertHead:soql]) {
        // save the current list of recent queries
		NSMutableArray *q = [NSMutableArray arrayWithCapacity:[[view items] count]];
		for (QueryTextListViewItem *i in [view items]) 
			[q addObject:[i text]];
			
		[[NSUserDefaults standardUserDefaults] setObject:q forKey:[self prefName:RECENT_QUERIES]];
	}
}

-(NSString *)prefName:(NSString *)name {
    return [NSString stringWithFormat:@"%@-%@", prefPrefix, name];
}

-(void)windowWillClose:(NSNotification *)notification {
    [self updateWindowVisibleState:NO triggerKVONotification:YES];
	[[window animator] setAlphaValue:0.0];
}

-(void)setDelegate:(id<QueryTextListViewDelegate>)delegate {
    [view setDelegate:delegate];
}

-(id<QueryTextListViewDelegate>)delegate {
    return [view delegate];
}

-(void)loadSavedItems {
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    NSArray *saved = [def arrayForKey:[self prefName:RECENT_QUERIES]];
    if (saved == nil) {
        // see if we need to migrate the existing items from the previous versions pref scheme.
        saved = [def arrayForKey:RECENT_QUERIES];
        if (saved != nil) {
            [def setObject:saved forKey:[self prefName:RECENT_QUERIES]];
            [def removeObjectForKey:RECENT_QUERIES];
        }
    }
	if (saved != nil)
        [view setInitialItems:saved];
}

-(void)checkShowWindow {
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    BOOL show = [def boolForKey:[self prefName:RECENT_SHOWN]];
    if (!show) {
        // migrate legacy setting
        if ([def objectForKey:RECENT_SHOWN] != nil) {
            show = [def boolForKey:RECENT_SHOWN];
            [def setBool:show forKey:[self prefName:RECENT_SHOWN]];
            [def removeObjectForKey:RECENT_SHOWN];
        }
    }
    if (show)
		[self setWindowVisible:TRUE];
}
    
-(NSString *)prefPrefix {
    return prefPrefix;
}

-(void)setPrefPrefix:(NSString *)pp {
    [prefPrefix autorelease];
    prefPrefix = [pp retain];
    [self loadSavedItems];
    [self checkShowWindow];
}

@end
