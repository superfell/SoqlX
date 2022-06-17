// Copyright (c) 2006-2016,2018,2021 Simon Fell
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

#import "ZKLoginController.h"
#import <ZKSforce/ZKSforce.h>
#import "credential.h"
#import "CredentialsController.h"
#import "Defaults.h"
#import "NSArray+Partition.h"

int DEFAULT_API_VERSION = 55;

// Holds any state that the UI might want to have bindings to.
// If a UI control has a binding to ZKLoginController directly
// then this creates a retain cycle and the LoginController
// instance never gets dealloc'd.
// Instead we have the UI bind to this separate object to break
// the retain cycle.

@interface LoginControllerState : NSObject {
    NSString *text;
}
@property (strong) NSString *statusText;
@property (assign) BOOL busy;
@property (weak) IBOutlet NSLayoutConstraint *statusHeightConstraint;
@end

@implementation LoginControllerState

-(void)showHideStatus {
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull ctx) {
        ctx.duration = 0.25;
        ctx.allowsImplicitAnimation = YES;
        BOOL show = self.busy || text.length > 0;
        self.statusHeightConstraint.constant = show ? 64 : 0;
    }];
}

-(void)setStatusText:(NSString *)statusText {
    text = statusText;
    [self showHideStatus];
}
-(NSString*)statusText {
    return text;
}
-(void)setIdle {
    self.busy = NO;
    self.statusText = @"";
}
-(void)setError:(NSString*)msg {
    self.busy = NO;
    self.statusText = msg;
}
-(void)setWorking:(NSString*)msg {
    self.busy = true;
    self.statusText = msg;
}

@end

@interface ZKLoginController()

@property (strong) NSWindow *modalWindow;
@property (strong) IBOutlet NSWindow *loginSheet;
@property (strong) IBOutlet NSTabView *tabView;
@property (strong) IBOutlet LoginTargetController *targetController;
@property (strong) IBOutlet CredentialsController *credsController;
@property (strong) IBOutlet LoginControllerState  *state;

-(IBAction)showLoginHelp:(id)sender;
-(void)closeLoginUi;

@end

@implementation ZKLoginController

+(NSString*)appClientId {
    NSDictionary *plist = [[NSBundle mainBundle] infoDictionary];
    NSString *cid = [NSString stringWithFormat:@"%@/%@", [plist objectForKey:@"CFBundleName"], [plist objectForKey:@"CFBundleVersion"]];
    return cid;
}

-(id)init {
    self = [super init];
    self.preferedApiVersion = DEFAULT_API_VERSION;
    self.controllerId = [[NSUUID UUID] UUIDString];
    return self;
}

-(void)dealloc {
    NSLog(@"LoginController dealloc");
}

-(void)awakeFromNib {
    self.credsController.delegate = self;
    [self.credsController reloadData];
    self.targetController.delegate = self;
    [self.targetController reloadData];
    if (self.credsController.hasSavedCredentials) {
        [self.tabView selectTabViewItemWithIdentifier:@"Saved"];
    } else {
        [self.tabView selectTabViewItemWithIdentifier:@"New"];
    }
    [self.state showHideStatus];
}

-(void)loginRowViewItem:(LoginRowViewItem*)i clicked:(id)cred {
    [self loginWithOAuthToken:cred window:self.modalWindow];
}

-(void)loginRowViewItem:(LoginRowViewItem*)i deleteClicked:(id)cred {
}

-(void)loadNib {
    [[NSBundle mainBundle] loadNibNamed:@"Login" owner:self topLevelObjects:nil];
}

-(void)endModalWindow:(id)sforce {
    [NSApp stopModal];
}

// the delegate will get a callback with the outcome
- (void)showLoginSheet:(NSWindow *)modalForWindow {
    [self loadNib];
    self.modalWindow = modalForWindow;
    [modalForWindow beginSheet:self.loginSheet completionHandler:nil];
}

-(void)closeLoginUi {
    [self.state setIdle];
    if (self.modalWindow != nil) {
        [NSApp endSheet:self.loginSheet];
        [self.loginSheet orderOut:self];
    } else {
        [self.loginSheet close];
    }
}

- (IBAction)cancelLogin:(id)sender {
    [self closeLoginUi];
    [self.delegate loginControllerLoginCancelled:self];
}

- (void)showAlertSheetWithMessageText:(NSString *)message 
            defaultButton:(NSString *)defaultButton 
            altButton:(NSString *)altButton
            completionHandler:(void (^ __nullable)(NSModalResponse returnCode))handler {
    
    NSAlert *a = [[NSAlert alloc] init];
    a.messageText = message;
    [a addButtonWithTitle:defaultButton];
    [a addButtonWithTitle:altButton];

    [NSApp endSheet:self.loginSheet];
    [self.loginSheet orderOut:self];
    
    [a beginSheetModalForWindow:self.modalWindow completionHandler:handler];
}

- (ZKSforceClient*)newClient:(int)version {
    ZKSforceClient *c = [[ZKSforceClient alloc] init];
    c.preferedApiVersion = version;
    [c setClientId:[ZKLoginController appClientId]];
    return c;
}

static NSString *OAUTH_CID = @"3MVG99OxTyEMCQ3hP1_9.Mh8dFxOk8gk6hPvwEgSzSxOs3HoHQhmqzBxALj8UBnhjzntUVXdcdZFXATXCdevs";

-(void)loginTargetSelected:(NSURL *)item {
    NSString *cb = @"soqlx://oauth/";
    // build the URL to the oauth page with our client_id & callback URL set.
    NSCharacterSet *urlcs = [NSCharacterSet URLQueryAllowedCharacterSet];
    NSString *path = [NSString stringWithFormat:@"/services/oauth2/authorize?response_type=token&client_id=%@&redirect_uri=%@&state=%@",
                       [OAUTH_CID stringByAddingPercentEncodingWithAllowedCharacters:urlcs],
                       [cb stringByAddingPercentEncodingWithAllowedCharacters:urlcs],
                       [self.controllerId stringByAddingPercentEncodingWithAllowedCharacters:urlcs]];
    NSURL *url = [NSURL URLWithString:path relativeToURL:item];

    // ask the OS to open browser to the URL
    [[NSWorkspace sharedWorkspace] openURL:url];
    self.state.statusText = @"Complete the login/authorization in the browser";
}

-(void)loginTargetDeleted:(NSURL *)item {
    // we don't care
}

-(void)addUserToMru:(NSString*)username host:(NSString*)hostname {
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    NSDictionary *mruEntry = @{
        LOGIN_MRU_USERNAME : username,
        LOGIN_MRU_HOST     : hostname,
    };
    NSUInteger existingIdx = [[def arrayForKey:DEF_LOGIN_MRU] indexOfObject:mruEntry];
    if (existingIdx != 0) {
        NSMutableArray *mru = [[def arrayForKey:DEF_LOGIN_MRU] mutableCopy];
        if (existingIdx != NSNotFound) {
            [mru removeObjectAtIndex:existingIdx];
        }
        [mru insertObject:mruEntry atIndex:0];
        [def setValue:mru forKey:DEF_LOGIN_MRU];
    }
}

-(void)openOAuthResponse:(NSURL *)url apiVersion:(int)apiVersion {
    ZKSforceClient *c = [self newClient:apiVersion];
    NSError *err = [c loginFromOAuthCallbackUrl:url.absoluteString oAuthConsumerKey:OAUTH_CID];
    if (err != nil) {
        [[NSAlert alertWithError:err] runModal];
        return;
    }
    // This call is used to validate that we were given a valid client, and that the auth info is usable.
    // This also ensures that the userInfo is cached, which subsequent code relies on.
    [self.state setWorking:@"Verifying OAuth tokens"];
    [self oauthCurrentUserInfoWithDowngrade:c
                                  failBlock:^(NSError *result) {
        [self.state setError:result.localizedDescription];
        [[NSAlert alertWithError:result] runModal];

    } completeBlock:^(ZKUserInfo *result) {
        ZKOAuthInfo *auth = (ZKOAuthInfo*)c.authenticationInfo;
        [self addUserToMru:result.userName host:auth.authHostUrl.host];
        
        // Success, see if there's an existing keychain entry for this oauth token
        NSArray<Credential*> *creds = [Credential credentials];
        for (Credential *cred in creds) {
            if ([cred.username isEqualToString:result.userName] && [cred.server.host isEqualToString:auth.authHostUrl.host]) {
                // update the keychain entry with the new refresh token
                [cred updateToken:auth.refreshToken];
                // and we're done
                [self closeLoginUi];
                [self.delegate loginController:self loginCompleted:c];
                return;
            }
        }
        // no keychain entry, ask user if they want one.
        [self showAlertSheetWithMessageText:@"Create Keychain entry with access token? This'll let you skip the login UI next time."
                    defaultButton:@"Create Keychain Entry"
                    altButton:@"No thanks"
                    completionHandler:^(NSModalResponse returnCode) {
                        if (NSAlertFirstButtonReturn == returnCode) {
                            [Credential createCredential:auth.authHostUrl
                                                username:result.userName
                                            refreshToken:auth.refreshToken];
                        }
                        [self closeLoginUi];
                        [self.delegate loginController:self loginCompleted:c];
                    }];
    }];
}

- (void)completeOAuthLogin:(NSURL *)oauthCallbackUrl window:(NSWindow*)modalForWindow {
    if (self.modalWindow == nil) {
        [self showLoginSheet:modalForWindow];
    }
    [self openOAuthResponse:oauthCallbackUrl apiVersion:self.preferedApiVersion];
}

-(void)oauthCurrentUserInfoWithDowngrade:(ZKSforceClient*)c
                               failBlock:(ZKFailWithErrorBlock)failBlock
                           completeBlock:(ZKCompleteUserInfoBlock)completeBlock {
    
    [c currentUserInfoWithFailBlock:^(NSError *result) {
        if ([result.userInfo[ZKSoapFaultCodeKey] hasSuffix:@":UNSUPPORTED_API_VERSION"]) {
            // not ideal
            ZKOAuthInfo *auth = (ZKOAuthInfo*)c.authenticationInfo;
            NSAssert([auth isKindOfClass:[ZKOAuthInfo class]], @"AuthInfo should be for OAuth");
            auth.apiVersion = auth.apiVersion-1;
            c.authenticationInfo = auth;
            //NSLog(@"Downgrading API version to %d due to error %@", auth.apiVersion, result);
            [self oauthCurrentUserInfoWithDowngrade:c failBlock:failBlock completeBlock:completeBlock];
            return;
        }
        failBlock(result);
    } completeBlock:completeBlock];
}

-(void)loginWithOAuthToken:(Credential*)cred window:(NSWindow*)modalForWindow {
    if (self.modalWindow == nil) {
        [self showLoginSheet:modalForWindow];
    }
    [self.state setWorking:@"Logging in from saved OAuth token"];
    ZKFailWithErrorBlock failBlock = ^(NSError *err) {
        [self.state setError:[NSString stringWithFormat:@"Refresh token no longer valid: %@", err.localizedDescription]];
    };

    ZKSforceClient *c = [self newClient:self.preferedApiVersion];
    [c loginWithRefreshToken:cred.token
                     authUrl:cred.server
            oAuthConsumerKey:OAUTH_CID
                   failBlock:failBlock
               completeBlock:^{
        [self oauthCurrentUserInfoWithDowngrade:c
                                      failBlock:failBlock
                                  completeBlock:^(ZKUserInfo *result) {
            [self closeLoginUi];
            [self addUserToMru:result.userName host:cred.server.host];
            [self.delegate loginController:self loginCompleted:c];
        }];
    }];
}

-(IBAction)showLoginHelp:(id)sender {
    NSString *help = [NSBundle mainBundle].infoDictionary[@"ZKHelpLoginUrl"];
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:help]];
}

@end
