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
#import "zkSforceClient.h"
#import "ZKLoginController.h"
#import "ZKSoapException.h"
#import "SessionIdAuthInfo.h"

@interface AppDelegate ()
@property (assign) BOOL startedFromOpenUrls;
@end

@implementation AppDelegate

@synthesize startedFromOpenUrls;

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

-(void)application:(NSApplication *)application openURLs:(NSArray<NSURL *> *)urls {
    for (NSURL *url in urls) {
        NSString *server = [url.host lowercaseString];
        if (!([server hasSuffix:@".salesforce.com"] || [server hasSuffix:@".force.com"])) {
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = @"Invalid SoqlX URL";
            alert.informativeText = @"supplied server must be a .salesforce.com or .force.com address";
            alert.alertStyle = NSAlertStyleWarning;
            [alert runModal];
            return;
        }
        if (![url.path hasPrefix:@"/sid/"]) {
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = @"Invalid SoqlX URL";
            alert.informativeText = @"expected to be soqlx://{salesforceServer}/sid/{sessionId}";
            alert.alertStyle = NSAlertStyleWarning;
            [alert runModal];
            return;
        }
        NSURL *instanceUrl = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/services/Soap/u/%d.0", url.host, DEFAULT_API_VERSION]];
        NSString *sid = [url.path substringFromIndex:6]; // remove /sid/ prefix
        SessionIdAuthInfo *auth = [[SessionIdAuthInfo alloc] initWithUrl:instanceUrl sessionId:sid];
        ZKSforceClient *c = [[ZKSforceClient alloc] init];
        [c setClientId:[ZKLoginController appClientId]];
        c.authenticationInfo = auth;
        @try {
            // This call is used to validate that we were given a valid client, and that the auth info is usable.
            [c currentUserInfo];
            // If the app was just stated to deal with this URL then openUrls is called before appDidFinishLaunching
            // so we can use this to stop our default window opening.
            self.startedFromOpenUrls = TRUE;
            SoqlXWindowController *controller = [[SoqlXWindowController alloc] initWithWindowControllers:windowControllers];
            [controller showWindowForClient:c];
            [windowControllers makeObjectsPerformSelector:@selector(closeLoginPanelIfOpen:) withObject:self];
            
        } @catch (ZKSoapException *ex) {
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = @"Invalid parameters";
            alert.informativeText = ex.reason;
            alert.alertStyle = NSAlertStyleWarning;
            [alert runModal];
        }
    }
}

-(void)applicationDidFinishLaunching:(NSNotification *)notification {
    [self resetApiVersionOverrideIfAppVersionChanged];
    if (!self.startedFromOpenUrls) {
        [self openNewWindow:self];
    }
    
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

@synthesize explorer;

-(instancetype)initWithWindowControllers:(NSMutableArray *)c {
    self = [super initWithWindowNibName:@"Explorer"];
    controllers = c;
    [c addObject:self];
    return self;
}

-(void)showWindowForClient:(ZKSforceClient*)client {
    [self window];    // forces Nib to be loaded, which'll set the explorer outlet/property
    [self.explorer useClient:client];
    [self showWindow:self];
}

-(void)closeLoginPanelIfOpen:(id)sender {
    [self.explorer closeLoginPanelIfOpen:sender];
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
