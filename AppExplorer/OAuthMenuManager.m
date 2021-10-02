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
#import "NSArray+Partition.h"

@interface OAuthMenuManager()
-(void)updateCredentialList;
@end

@implementation OAuthMenuManager

OSStatus keychainCallback (SecKeychainEvent keychainEvent, SecKeychainCallbackInfo *info, void *context) {
    OAuthMenuManager *ac = (__bridge OAuthMenuManager*)context;
    [ac updateCredentialList];
    return noErr;
}

-(void)dealloc {
    SecKeychainRemoveCallback(keychainCallback);
}

-(void)awakeFromNib {
    OSStatus s = SecKeychainAddCallback(keychainCallback, kSecAddEventMask | kSecDeleteEventMask | kSecUpdateEventMask, (__bridge void * _Nullable)(self));
    if (s != noErr) {
        NSLog(@"Unable to register for keychain changes, got error %ld", (long)s);
    }
    [self updateCredentialList];
}

-(void)updateCredentialList {
    NSArray<Credential*>* all = [Credential credentials];
    NSArray<NSArray<Credential*>*> *byServer = [all partitionByKeyPath:@"server.host"];

    BOOL addSeparator = FALSE;
    NSMenu *menu = self.menu.submenu;
    [menu removeAllItems];
    for (NSArray<Credential*> *credentials in byServer) {
        if (addSeparator) {
            [menu addItem:[NSMenuItem separatorItem]];
        }
        NSMenuItem *s = [[NSMenuItem alloc] initWithTitle:credentials[0].server.friendlyHostLabel action:nil keyEquivalent:@""];
        [menu addItem:s];
        for (Credential *c in credentials) {
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:c.username action:nil keyEquivalent:@""];
            [item setRepresentedObject:c];
            [item setTarget:[NSApp delegate]];
            [item setAction:@selector(openNewWindowForOAuthCredential:)];
            [menu addItem:item];
        }
        addSeparator = TRUE;
    }
    self.all = all;
}

@end
