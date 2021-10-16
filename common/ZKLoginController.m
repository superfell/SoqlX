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
#import "CredentialsDataSource.h"
#import "Defaults.h"

int DEFAULT_API_VERSION = 53;

@interface ZKLoginController()

// items in the UI using bindings read these and drive the UI
@property (strong) NSString *statusText;
@property (assign) BOOL busy;
@property (readonly) BOOL hasSavedCredentials;
@property (assign) BOOL isEditing;
-(NSString*)sheetHeaderText;
-(NSString*)welcomeText;
-(IBAction)toggleEditing:(id)sender;
-(IBAction)showLoginHelp:(id)sender;


@property (strong) NSWindow *modalWindow;
@property (strong) IBOutlet NSWindow *loginSheet;
@property (strong) IBOutlet NSCollectionView *savedLogins;
@property (strong) IBOutlet NSPopover *loginDest;
@property (strong) IBOutlet NSButton *loginButton;
@property (strong) IBOutlet LoginTargetController *targetController;
-(IBAction)startOAuthLogin:(id)sender;
-(void)closeLoginUi;


@property (strong) Credential *selectedCredential;
@property (strong) CredentialsDataSource *credDataSource;

@end

@implementation ZKLoginController

+(NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
    NSSet *paths = [super keyPathsForValuesAffectingValueForKey:key];
    if ([key isEqualToString:@"hasSavedCredentials"]
        || [key isEqualToString:@"sheetHeaderText"]) {
        return [paths setByAddingObject:@"credDataSource"];
    }
    return paths;
}

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

-(void)awakeFromNib {
    [self.savedLogins registerNib:[[NSNib alloc] initWithNibNamed:@"LoginRowViewItem" bundle:nil] forItemWithIdentifier:@"row"];
    [self.savedLogins registerNib:[[NSNib alloc] initWithNibNamed:@"LoginHeaderRowViewItem" bundle:nil]
         forSupplementaryViewOfKind:NSCollectionElementKindSectionHeader
                     withIdentifier:@"h"];
    self.savedLogins.selectable = YES;
    self.credDataSource = [[CredentialsDataSource alloc] initWithCreds:[Credential credentialsInMruOrder]];
    self.credDataSource.delegate = self;
    self.savedLogins.dataSource = self.credDataSource;
    self.targetController.delegate = self;
}

-(BOOL)hasSavedCredentials {
    return self.credDataSource.items.count > 0;
}

-(IBAction)toggleEditing:(id)sender {
    self.isEditing = !self.isEditing;
    self.credDataSource.isEditing = self.isEditing;
    [self.savedLogins reloadData];
}

-(void)credentialSelected:(Credential*)c {
    [self loginWithOAuthToken:c window:self.modalWindow];
}

- (void)deleteCredential:(nonnull Credential *)c {
    [self.credDataSource removeItem:c];
    [self.savedLogins reloadData];
    [c deleteEntry];
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
    // TODO: can auto layout handle this now?
    NSSize fr = self.loginSheet.contentView.frame.size;
    NSSize visSize = self.savedLogins.frame.size;
    NSSize allItems = self.savedLogins.collectionViewLayout.collectionViewContentSize;
    CGFloat newHeight = MAX(260.0, fr.height - visSize.height + allItems.height);
    [self.loginSheet setContentSize:NSMakeSize(fr.width, newHeight)];
 
    // This reloadData shouldn't be needed, but without it, the section header sometimes
    // get placed over the first item, not above it.
    [self.savedLogins reloadData];
    if (self.credDataSource.items.count > 0) {
        NSIndexPath *first = [NSIndexPath indexPathForItem:0 inSection:0];
        [self.savedLogins setSelectionIndexPaths:[NSSet setWithObject:first]];
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

-(IBAction)startOAuthLogin:(id)sender {
    NSRect btnRect = self.loginButton.bounds;
    [self.loginDest showRelativeToRect:btnRect ofView:self.loginButton preferredEdge:NSRectEdgeMaxX];
}

-(void)loginTargetSelected:(LoginTargetItem*)item {
    NSString *cb = @"soqlx://oauth/";
    // build the URL to the oauth page with our client_id & callback URL set.
    NSCharacterSet *urlcs = [NSCharacterSet URLQueryAllowedCharacterSet];
    NSString *path = [NSString stringWithFormat:@"/services/oauth2/authorize?response_type=token&client_id=%@&redirect_uri=%@&state=%@",
                       [OAUTH_CID stringByAddingPercentEncodingWithAllowedCharacters:urlcs],
                       [cb stringByAddingPercentEncodingWithAllowedCharacters:urlcs],
                       [self.controllerId stringByAddingPercentEncodingWithAllowedCharacters:urlcs]];
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
    self.busy = TRUE;
    self.statusText = @"Verifying OAuth tokens";
    [self oauthCurrentUserInfoWithDowngrade:c
                                  failBlock:^(NSError *result) {
        self.busy = FALSE;
        self.statusText = result.localizedDescription;
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
        [self showAlertSheetWithMessageText:@"Create Keychain entry with access token?"
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
    [self setStatusText:@"Logging in from saved OAuth token"];
    self.busy = TRUE;
    ZKFailWithErrorBlock failBlock = ^(NSError *err) {
        self.statusText = [NSString stringWithFormat:@"Refresh token no longer valid: %@", err.localizedDescription];
        self.busy = FALSE;
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

-(NSString*)welcomeText {
    return NSLocalizedString(@"WelcomeText", @"text shown in the login sheet when there's no saved credentials");
}

-(IBAction)showLoginHelp:(id)sender {
    NSString *help = [NSBundle mainBundle].infoDictionary[@"ZKHelpLoginUrl"];
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:help]];
}

-(NSString*)sheetHeaderText {
    return self.hasSavedCredentials ?
        NSLocalizedString(@"SheetHeaderLogins", @"show on the login sheet when there are saved logins") :
        NSLocalizedString(@"SheetHeaderWelcome", @"shown on the login sheet when there are no saved logins");
}

@end
