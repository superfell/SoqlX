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
#import "AppDelegate.h"
#import "OAuthMenuManager.h"
#import "LoginRowViewItem.h"

int DEFAULT_API_VERSION = 53;

static int nextControllerId = 42;

@interface CredDataSource : NSObject<NSCollectionViewDataSource>
-(id)initWithCreds:(NSArray<Credential*>*)creds;
@property (strong) NSArray<Credential*>             *items;
@property (weak) NSObject<LoginRowViewItemDelegate> *delegate;
@end


@interface ZKLoginController ()
@property (strong) Credential *selectedCredential;
@property (strong) CredDataSource *credDataSource;
-(void)closeLoginUi;
@end

@implementation CredDataSource

-(id)initWithCreds:(NSArray<Credential *> *)creds {
    self = [super init];
    self.items = creds;
    return self;
}

-(NSInteger)collectionView:(nonnull NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.items.count;
}

-(nonnull NSCollectionViewItem *)collectionView:(nonnull NSCollectionView *)collectionView
            itemForRepresentedObjectAtIndexPath:(nonnull NSIndexPath *)indexPath {
    Credential *c = self.items[indexPath.item];
    LoginRowViewItem *i = [collectionView makeItemWithIdentifier:@"row" forIndexPath:indexPath];
    i.credential = c;
    i.delegate = self.delegate;
    return i;
}

@end

@interface ZKLoginController()

-(IBAction)startOAuthLogin:(id)sender;

@property (strong) NSString *statusText;
@property (assign) BOOL busy;

@property (strong) NSWindow *modalWindow;
@property (strong) IBOutlet NSWindow *loginSheet;
@property (strong) IBOutlet NSCollectionView *savedLogins;
@property (strong) IBOutlet NSPopover *loginDest;
@property (strong) IBOutlet NSButton *loginButton;
@property (strong) IBOutlet LoginTargetController *targetController;

@end

@implementation ZKLoginController

static NSString *login_lastOAuthUsernameKey = @"login_lastOAuthUserName";
static NSString *login_lastOAuthServer = @"login_lastOAuthServer";
static NSString *login_lastLoginType = @"login_lastType";

+(NSString*)appClientId {
    NSDictionary *plist = [[NSBundle mainBundle] infoDictionary];
    NSString *cid = [NSString stringWithFormat:@"%@/%@", [plist objectForKey:@"CFBundleName"], [plist objectForKey:@"CFBundleVersion"]];
    return cid;
}

-(id)init {
    self = [super init];
    self.preferedApiVersion = DEFAULT_API_VERSION;
    self.controllerId = [NSString stringWithFormat:@"c%d", nextControllerId++];
    return self;
}

- (void)awakeFromNib {
    [self.savedLogins registerNib:[[NSNib alloc] initWithNibNamed:@"LoginRowViewItem" bundle:nil] forItemWithIdentifier:@"row"];
    AppDelegate *d = (AppDelegate*) [NSApp delegate];
    self.credDataSource = [[CredDataSource alloc] initWithCreds:d.oauthManager.all];
    self.credDataSource.delegate = self;
    self.savedLogins.dataSource = self.credDataSource;
    self.targetController.delegate = self;
}

-(void)credentialSelected:(Credential*)c {
    [self loginWithOAuthToken:c window:self.modalWindow];
}

- (void)loadNib {
    [[NSBundle mainBundle] loadNibNamed:@"Login" owner:self topLevelObjects:nil];
}

- (void)endModalWindow:(id)sforce {
    [NSApp stopModal];
}

// the delegate will get a callback with the outcome
- (void)showLoginSheet:(NSWindow *)modalForWindow {
    [self loadNib];
    self.modalWindow = modalForWindow;
    if (self.credDataSource.items.count > 2) {
        NSRect f = self.loginSheet.frame;
        f.size.height = self.credDataSource.items.count * 60 + 270 - 120;
        [self.loginSheet setContentSize:f.size];
    }
    [modalForWindow beginSheet:self.loginSheet completionHandler:nil];
}

-(void)closeLoginUi {
    self.busy = FALSE;
    self.statusText = @"";
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

- (IBAction)startOAuthLogin:(id)sender {
    NSRect btnRect = self.loginButton.bounds;
    [self.loginDest showRelativeToRect:btnRect ofView:self.loginButton preferredEdge:NSRectEdgeMaxX];
}

-(void)loginTargetSelected:(LoginTargetItem*)item {
    NSString *cb = @"soqlx://oauth/";
    // build the URL to the oauth page with our client_id & callback URL set.
    NSString *path = [NSString stringWithFormat:@"/services/oauth2/authorize?response_type=token&client_id=%@&redirect_uri=%@&state=%@",
                       [OAUTH_CID stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]],
                       [cb stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]],
                       self.controllerId];
    NSURL *url = [NSURL URLWithString:path relativeToURL:item.url];

    // ask the OS to open browser to the URL
    [[NSWorkspace sharedWorkspace] openURL:url];
    self.statusText = @"Complete the login/authorization in the browser";
    // close the login target popup
    [self.loginDest performClose:self];
}

-(void)loginTargetDeleted:(nonnull LoginTargetItem *)item {
    // we don't care
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
    self.busy = TRUE;
    self.statusText = @"Verifying OAuth tokens";
    [self oauthCurrentUserInfoWithDowngrade:c
                                  failBlock:^(NSError *result) {
        self.busy = FALSE;
        self.statusText = result.localizedDescription;
        [[NSAlert alertWithError:result] runModal];

    } completeBlock:^(ZKUserInfo *result) {
        ZKOAuthInfo *auth = (ZKOAuthInfo*)c.authenticationInfo;
        NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
        [def setObject:result.userName forKey:login_lastOAuthUsernameKey];
        [def setObject:auth.authHostUrl.absoluteString forKey:login_lastOAuthServer];
        [def setObject:@"OAUTH" forKey:login_lastLoginType];
        
        // Success, see if there's an existing keychain entry for this oauth token
        NSArray<Credential*> *creds = [Credential credentialsForServer:auth.authHostUrl.absoluteString];
        for (Credential *cred in creds) {
            if ((cred.type == ctRefreshToken) && ([cred.username isEqualToString:result.userName])) {
                // update the keychain entry with the new refresh token
                [cred updatePassword:auth.refreshToken];
                // and we're done
                [self closeLoginUi];
                [self.delegate loginController:self loginCompleted:c];
                return;
            }
        }
        // no keychain entry, ask user if they want one.
        [self showAlertSheetWithMessageText:@"Create Keychain entry with access token?"
                    defaultButton:@"Create Keychain Entry"
                    altButton:@"No thanks"
                    completionHandler:^(NSModalResponse returnCode) {
                        if (NSAlertFirstButtonReturn == returnCode) {
                            [Credential createOAuthCredential:auth.authHostUrl.absoluteString
                                                     username:result.userName
                                                 refreshToken:auth.refreshToken];
                        }
                        [self closeLoginUi];
                        [self.delegate loginController:self loginCompleted:c];
                    }];
    }];
}

- (void)completeOAuthLogin:(NSURL *)oauthCallbackUrl {
    [self openOAuthResponse:oauthCallbackUrl apiVersion:self.preferedApiVersion];
}

// returns the keychain entry for the most recent oauth login
// if the most recent login was oauth, and the user opted to
// create the keychain entry for the refresh token. Otherwise
// returns nil.
- (Credential*)lastOAuthCredential {
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    if (![[def objectForKey:login_lastLoginType] isEqualToString:@"OAUTH"]) {
        return nil;
    }
    NSString *server = [def objectForKey:login_lastOAuthServer];
    NSString *username = [def objectForKey:login_lastOAuthUsernameKey];
    if (server == nil || username == nil) {
        // Should never happen
        return nil;
    }
    NSArray<Credential*> *creds = [Credential credentialsForServer:server];
    for (Credential *c in creds) {
        if ((c.type == ctRefreshToken) && [c.username isEqualToString:username]) {
            return c;
        }
    }
    return nil;
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
            NSLog(@"Downgrading API version to %d due to error %@", auth.apiVersion, result);
            [self oauthCurrentUserInfoWithDowngrade:c failBlock:failBlock completeBlock:completeBlock];
            return;
        }
        failBlock(result);
    } completeBlock:completeBlock];
}

-(void)loginWithLastOAuthToken:(NSWindow *)modalForWindow {
    [self showLoginSheet:modalForWindow];
    Credential *cred = [self lastOAuthCredential];
    if (cred != nil) {
        [self loginWithOAuthToken:cred window:modalForWindow];
    }
}

-(void)loginWithOAuthToken:(Credential*)cred window:(NSWindow*)modalForWindow {
    if (self.modalWindow == nil) {
        [self showLoginSheet:modalForWindow];
    }
    [self setStatusText:@"Logging in from saved OAuth token"];
    self.busy = TRUE;
    ZKFailWithErrorBlock failBlock = ^(NSError *err) {
        self.statusText = [NSString stringWithFormat:@"Refresh token no longer valid: %@", err.localizedDescription];
        self.busy = FALSE;
    };

    ZKSforceClient *c = [self newClient:self.preferedApiVersion];
    [c loginWithRefreshToken:cred.password
                     authUrl:[NSURL URLWithString:cred.server]
            oAuthConsumerKey:OAUTH_CID
                   failBlock:failBlock
               completeBlock:^{
        [self oauthCurrentUserInfoWithDowngrade:c
                                      failBlock:failBlock
                                  completeBlock:^(ZKUserInfo *result) {
            [self closeLoginUi];
            [self.delegate loginController:self loginCompleted:c];
        }];
    }];
}

@end
