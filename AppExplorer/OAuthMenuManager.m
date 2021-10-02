// Copyright (c) 2021 Simon Fell
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

#import "OAuthMenuManager.h"
#import "credential.h"
#import "AppDelegate.h"

@interface OAuthMenuManager()
-(void)updateCredentialList;
@end

@implementation OAuthMenuManager

OSStatus keychainCallback (SecKeychainEvent keychainEvent, SecKeychainCallbackInfo *info, void *context) {
    OAuthMenuManager *ac = (__bridge OAuthMenuManager*)context;
    [ac updateCredentialList];
    return noErr;
}

- (void)dealloc {
    [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:@"servers"];
    SecKeychainRemoveCallback(keychainCallback);
}

- (void)awakeFromNib {
    OSStatus s = SecKeychainAddCallback(keychainCallback, kSecAddEventMask | kSecDeleteEventMask | kSecUpdateEventMask, (__bridge void * _Nullable)(self));
    if (s != noErr) {
        NSLog(@"Unable to register for keychain changes, got error %ld", (long)s);
    }
    [[NSUserDefaults standardUserDefaults] addObserver:self
                                            forKeyPath:@"servers"
                                               options:NSKeyValueObservingOptionInitial
                                               context:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(void *)context {
    [self updateCredentialList];
}

-(void)updateCredentialList {
    NSMutableArray<NSString*> *servers = [[NSMutableArray alloc] initWithCapacity:4];
    NSMutableArray<Credential*>* allCreds = [NSMutableArray arrayWithCapacity:4];
    
    // Because we've been siliently mapping www -> login, login.salesforce.com might not appear
    // in the prefs list of servers, but could have oauth tokens for it. So we manually add that
    // in to the list to check.
    [servers addObject:@"https://login.salesforce.com"];
    [[[NSUserDefaults standardUserDefaults] objectForKey:@"servers"] enumerateObjectsUsingBlock:^(NSString *  _Nonnull server, NSUInteger idx, BOOL * _Nonnull stop) {
        for (NSString *existing in servers) {
            if ([existing caseInsensitiveCompare:server] == NSOrderedSame) {
                return;
            }
        }
        [servers addObject:server];
    }];
    BOOL addSeparator = FALSE;
    NSMenu *menu = self.menu.submenu;
    [menu removeAllItems];
    for (NSString *server in servers) {
        NSArray<Credential*> *credentials = [Credential credentialsForServer:[NSURL URLWithString:server]];
        credentials = [credentials filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"type=%d", ctRefreshToken]];
        if (credentials.count == 0) {
            continue;
        }
        if (addSeparator) {
            [menu addItem:[NSMenuItem separatorItem]];
        }
        NSMenuItem *s = [[NSMenuItem alloc] initWithTitle:server action:nil keyEquivalent:@""];
        [menu addItem:s];
        for (Credential *c in credentials) {
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:c.username action:nil keyEquivalent:@""];
            [item setRepresentedObject:c];
            [item setTarget:[NSApp delegate]];
            [item setAction:@selector(openNewWindowForOAuthCredential:)];
            [menu addItem:item];
        }
        [allCreds addObjectsFromArray:credentials];
        addSeparator = TRUE;
    }
    self.all = allCreds;
}

@end
