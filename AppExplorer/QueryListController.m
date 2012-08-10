// Copyright (c) 2008 Simon Fell
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

NSString *RECENT_QUERIES = @"recentQueries";

@implementation QueryListController

-(void)awakeFromNib {
	[window setContentBorderThickness:28.0 forEdge:NSMinYEdge];
	[window setAlphaValue:0.0];
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"recentQueriesVisible"])
		[self showHideWindow:self];
}

-(IBAction)showHideWindow:(id)sender {
	[window displayOrCloseWindow:sender];
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
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"recentQueriesVisible"];
	[[window animator] setAlphaValue:0.0];
}

-(void)setDelegate:(id<QueryTextListViewDelegate>)delegate {
    [view setDelegate:delegate];
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

-(NSString *)prefPrefix {
    return prefPrefix;
}

-(void)setPrefPrefix:(NSString *)pp {
    [prefPrefix autorelease];
    prefPrefix = [pp retain];
    [self loadSavedItems];
}

@end
