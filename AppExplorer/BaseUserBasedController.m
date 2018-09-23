// Copyright (c) 2012 Simon Fell
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

#import "BaseUserBasedController.h"
#import "NSWindow_additions.h"

@implementation BaseUserBasedController


-(NSString *)prefName:(NSString *)pref {
    return [NSString stringWithFormat:@"%@-%@", prefsPrefix, pref];
}

-(void)onPrefsPrefixSet:(NSString *)newPrefix {
    // subclasses can override this if they need to do anything when the
    // prefs prefix gets set.
}

-(NSString *)prefsPrefix {
    return prefsPrefix;
}

-(void)setPrefsPrefix:(NSString *)pp {
    prefsPrefix = pp;
    [self onPrefsPrefixSet:pp];
}

@end

@implementation BaseWindowToggleController

-(void)awakeFromNib {
    panelWindow.alphaValue = 0.0;
    panelWindow.delegate = self;
    visible = NO;
    terminating = NO;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillTerminate:) name:NSApplicationWillTerminateNotification object:nil];
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(NSString *)windowVisiblePrefName {
    @throw [[NSException alloc] initWithName:@"ABSTRACT_METHOD" reason:@"subclasses need to implement windowVisiblePrefName" userInfo:nil];
}

-(BOOL)windowVisible {
    return visible;
}

-(void)appWillTerminate:(NSNotification *)n {
    terminating = YES;
}

-(void)setWindowVisible:(BOOL)windowVisible updateWindow:(BOOL)updateWindow {
    if (visible == windowVisible) return;
    visible = windowVisible;
    if (!terminating)
        [[NSUserDefaults standardUserDefaults] setBool:visible forKey:[self prefName:[self windowVisiblePrefName]]];
    if (updateWindow)
        [panelWindow displayOrClosePanel:self forMainWindow:mainWindow];
}

-(void)setWindowVisible:(BOOL)windowVisible {
    [self setWindowVisible:windowVisible updateWindow:YES];
}

-(void)windowWillClose:(NSNotification *)notification {
    [self willChangeValueForKey:@"windowVisible"];
    [self setWindowVisible:NO updateWindow:NO];
    [self didChangeValueForKey:@"windowVisible"];
    [panelWindow animator].alphaValue = 0.0;
    [panelWindow.parentWindow removeChildWindow:panelWindow];
}

-(void)onPrefsPrefixSet:(NSString *)pp {
    NSString *oldPrefName = [self windowVisiblePrefName];
    NSString *newPrefName = [self prefName:oldPrefName];
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    BOOL show = [def boolForKey:newPrefName];
    // migrate old setting if needed
    if (!show && [def objectForKey:oldPrefName] != nil) {
        show = [def boolForKey:oldPrefName];
        [def setBool:show forKey:newPrefName];
        [def removeObjectForKey:oldPrefName];
    }
    if (show)
        [self setWindowVisible:YES];
}

@end
