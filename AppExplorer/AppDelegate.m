// Copyright (c) 2012-2015 Simon Fell
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

#import "AppDelegate.h"
#import "Explorer.h"
#import "Prefs.h"
#import <Sparkle/Sparkle.h>

@implementation AppDelegate

-(instancetype)init {
    self = [super init];
    windowControllers = [[NSMutableArray alloc] init];
    return self;
}


- (IBAction)launchHelp:(id)sender {
    NSString *help = [NSBundle mainBundle].infoDictionary[@"ZKHelpUrl"];
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:help]];
}

// If the version of the app has changed, then reset any pref setting that is overriding the API version from
// the default (as a new version likely means we've moved API versions anyway)
-(void)resetApiVersionOverrideIfAppVersionChanged {
    NSDictionary *plist = [NSBundle mainBundle].infoDictionary;
    NSString * currentVersionString = plist[@"CFBundleVersion"];
    float currentVersion = currentVersionString == nil ? 0.0f : currentVersionString.floatValue;
    float lastRun = [[NSUserDefaults standardUserDefaults] floatForKey:@"LastAppVersionRun"];
    if (currentVersion > lastRun) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"zkApiVersion"];
        [[NSUserDefaults standardUserDefaults] setFloat:currentVersion forKey:@"LastAppVersionRun"];
    }
}

-(void)applicationDidFinishLaunching:(NSNotification *)notification {
    [self resetApiVersionOverrideIfAppVersionChanged];
    [self openNewWindow:self];
    
    // If the updater is going to restart the app, we need to close the login sheet if its currently open.
    [[SUUpdater sharedUpdater] setDelegate:self];
}

-(void)openNewWindow:(id)sender {
    NSWindowController *controller = [[SoqlXWindowController alloc] initWithWindowControllers:windowControllers];
    [controller showWindow:sender];
}

// Sparkle : SUUpdaterDelegate - Called immediately before relaunching.
- (void)updaterWillRelaunchApplication:(SUUpdater *)updater {
    [windowControllers makeObjectsPerformSelector:@selector(closeLoginPanelIfOpen:) withObject:updater];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return [[NSUserDefaults standardUserDefaults] boolForKey:PREF_QUIT_ON_LAST_WINDOW_CLOSE];
}

@end

@implementation SoqlXWindowController

-(instancetype)initWithWindowControllers:(NSMutableArray *)c {
    self = [super initWithWindowNibName:@"Explorer"];
    controllers = c;
    [c addObject:self];
    return self;
}


-(void)closeLoginPanelIfOpen:(id)sender {
    Explorer *e = (Explorer *)self.window.delegate;
    [e closeLoginPanelIfOpen:sender];
}

-(void)windowDidLoad {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowWillClose:) name:NSWindowWillCloseNotification object:self.window];
}

-(void)windowWillClose:(id)sender {
    // when the window gets closed, remove ourselves from the list of window controllers.
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [controllers removeObject:self];
}

@end
