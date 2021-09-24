// Copyright (c) 2006-2016,2018 Simon Fell
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
#import "credential.h"


int DEFAULT_API_VERSION = 53;

static int nextControllerId = 42;

@interface ZKLoginController ()
@property (strong) Credential *selectedCredential;
-(void)closeLoginUi;
@end

@implementation ZKLoginController

@synthesize clientId, urlOfNewServer, statusText, password, preferedApiVersion, delegate, selectedCredential;
@synthesize tokenWindow, apiSecurityToken, controllerId;

static NSString *login_lastUsernameKey = @"login_lastUserName";
static NSString *login_lastOAuthUsernameKey = @"login_lastOAuthUserName";
static NSString *login_lastOAuthServer = @"login_lastOAuthServer";
static NSString *login_lastLoginType = @"login_lastType";

static NSString *prod = @"https://www.salesforce.com";
static NSString *test = @"https://test.salesforce.com";


+(NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
    NSSet *paths = [super keyPathsForValuesAffectingValueForKey:key];
    if ([key isEqualToString:@"password"]) 
        return [paths setByAddingObject:@"username"];
    if ([key isEqualToString:@"credentials"] || [key isEqualToString:@"canDeleteServer"])
        return [paths setByAddingObject:@"server"];
    return paths;
}

+ (NSSet *)keyPathsForValuesAffectingHasEnteredToken {
    return [NSSet setWithObject:@"apiSecurityToken"];
}

+ (NSString*)appClientId {
    NSDictionary *plist = [[NSBundle mainBundle] infoDictionary];
    NSString *cid = [NSString stringWithFormat:@"%@/%@", [plist objectForKey:@"CFBundleName"], [plist objectForKey:@"CFBundleVersion"]];
    return cid;
}

- (id)init {
    self = [super init];
    server = [[[NSUserDefaults standardUserDefaults] objectForKey:@"server"] copy];
    [self setUsername:[[NSUserDefaults standardUserDefaults] objectForKey:login_lastUsernameKey]];
    preferedApiVersion = DEFAULT_API_VERSION;
    self.controllerId = [NSString stringWithFormat:@"c%d", nextControllerId++];
    return self;
}

- (void)awakeFromNib {
    [loginProgress setUsesThreadedAnimation:YES];
    [loginProgress setHidden:YES];
    [loginProgress setDoubleValue:22.0];
}

- (void)loadNib {
    NSArray *top = nibTopLevelObjects;
    [[NSBundle mainBundle] loadNibNamed:@"Login" owner:self topLevelObjects:&top];
    nibTopLevelObjects = top;
}

- (void)setClientIdFromInfoPlist {
    [self setClientId:[ZKLoginController appClientId]];
}

- (void)endModalWindow:(id)sforce {
    [NSApp stopModal];
}

// the delegate will get a callback with the outcome
- (void)showLoginSheet:(NSWindow *)modalForWindow {
    [self loadNib];
    modalWindow = modalForWindow;
    [modalForWindow beginSheet:window completionHandler:nil];
}

- (BOOL)canDeleteServer {
    return ([server caseInsensitiveCompare:prod] != NSOrderedSame) && ([server caseInsensitiveCompare:test] != NSOrderedSame);
}

- (IBAction)showAddNewServer:(id)sender {
    [self setUrlOfNewServer:@"https://"];
    [NSApp endSheet:window];
    [window orderOut:sender];
    [modalWindow beginSheet:newUrlWindow completionHandler:^(NSModalResponse returnCode) {
        [self->window orderOut:self];
        [self->modalWindow beginSheet:self->window completionHandler:nil];
    }];
}

- (IBAction)closeAddNewServer:(id)sender {
    [NSApp endSheet:newUrlWindow];    
    [newUrlWindow orderOut:sender];
}

- (IBAction)deleteServer:(id)sender {
    if (![self canDeleteServer]) return;
    NSString *removedServer = [self server];
    NSArray *servers = [[NSUserDefaults standardUserDefaults] objectForKey:@"servers"];
    NSMutableArray *newServers = [NSMutableArray arrayWithCapacity:[servers count]];
    for (NSString *s in servers) {
        if ([s caseInsensitiveCompare:removedServer] == NSOrderedSame) continue;
        [newServers addObject:s];
    }
    [[NSUserDefaults standardUserDefaults] setObject:newServers forKey:@"servers"];
    [self setServer:prod];
    if ([delegate respondsToSelector:@selector(loginController:serverUrlRemoved:)])
        [delegate loginController:self serverUrlRemoved:[NSURL URLWithString:removedServer]];
}

- (IBAction)addNewServer:(id)sender {
    NSString *new = [self urlOfNewServer];
    if (![new isEqualToString:@"https://"]) {
        NSArray *servers = [[NSUserDefaults standardUserDefaults] objectForKey:@"servers"];
        if (![servers containsObject:new]) {
            NSArray *newServers = [servers arrayByAddingObject:new];
            [[NSUserDefaults standardUserDefaults] setObject:newServers forKey:@"servers"];
        }
        [self setServer:new];
        [self closeAddNewServer:sender];
        if ([delegate respondsToSelector:@selector(loginController:serverUrlAdded:)])
            [delegate loginController:self serverUrlAdded:[NSURL URLWithString:new]];
    }
}

-(void)closeLoginUi {
    if (modalWindow != nil) {
        [NSApp endSheet:window];
        [window orderOut:self];
    } else {
        [window close];
    }
}

- (IBAction)cancelLogin:(id)sender {
    [self closeLoginUi];
    if ([delegate respondsToSelector:@selector(loginControllerLoginCancelled:)])
        [delegate loginControllerLoginCancelled:self];
}

- (void)showAlertSheetWithMessageText:(NSString *)message 
            defaultButton:(NSString *)defaultButton 
            altButton:(NSString *)altButton
            completionHandler:(void (^ __nullable)(NSModalResponse returnCode))handler {
    
    NSAlert *a = [[NSAlert alloc] init];
    a.messageText = message;
    [a addButtonWithTitle:defaultButton];
    [a addButtonWithTitle:altButton];

    [NSApp endSheet:window];
    [window orderOut:self];
    
    [a beginSheetModalForWindow:modalWindow completionHandler:handler];
}

- (void)promptAndAddToKeychain {
    [self showAlertSheetWithMessageText:@"Create Keychain entry with new username & password?" 
                defaultButton:@"Create Keychain Entry" 
                altButton:@"No thanks"
                completionHandler:^(NSModalResponse returnCode) {
                    if (NSAlertFirstButtonReturn == returnCode) {
                         [Credential createCredentialForServer:self->server username:self->username password:self->password];
                    }
                    [self closeLoginUi];
                    [self.delegate loginController:self loginCompleted:self->sforce];
                }];
}

- (void)promptAndUpdateKeychain {
    [self showAlertSheetWithMessageText:@"Update Keychain entry with new password?" 
                defaultButton:@"Update Keychain" 
                altButton:@"No thanks"
                completionHandler:^(NSModalResponse returnCode) {
                    if (NSAlertFirstButtonReturn == returnCode) {
                         [[self selectedCredential] updatePassword:self->password];
                    }
                    [self closeLoginUi];
                    [self.delegate loginController:self loginCompleted:self->sforce];
                }];
}

- (ZKSforceClient*)newClient:(int)version {
    ZKSforceClient *c = [[ZKSforceClient alloc] init];
    c.preferedApiVersion = version;
    if ([clientId length] > 0) {
        [c setClientId:clientId];
    }
    return c;
}

- (void)startLoginWithApiVersion:(int)version
                       failBlock:(ZKFailWithErrorBlock)failBlock
                   completeBlock:(void(^)(ZKSforceClient *client))completeBlock {
    
    ZKSforceClient *newClient = [self newClient:version];
    sforce = newClient;
    [newClient setLoginProtocolAndHost:server andVersion:version];
    
    [newClient login:username password:password failBlock:^(NSError *result) {
        if ([result.userInfo[ZKSoapFaultCodeKey] hasSuffix:@":UNSUPPORTED_API_VERSION"]) {
            NSLog(@"Login failed with %@ on API Version %d, retrying with version %d", result, version, version-1);
            [self startLoginWithApiVersion:version-1 failBlock:failBlock completeBlock:completeBlock];
        } else {
            failBlock(result);
        }
    } completeBlock:^(ZKLoginResult *result) {
        NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
        [def setObject:self.server forKey:@"server"];
        [def setObject:self.username forKey:login_lastUsernameKey];
        [def setObject:@"SOAP" forKey:login_lastLoginType];
        completeBlock(newClient);
    }];
}

-(void)startLogin:(ZKFailWithErrorBlock)failBlock completeBlock:(void(^)(ZKSforceClient *client))completeBlock {
    [self startLoginWithApiVersion:preferedApiVersion failBlock:failBlock completeBlock:completeBlock];
}
            
- (IBAction)login:(id)sender {
    [self setStatusText:nil];
    [loginProgress setHidden:NO];
    [loginProgress display];
    [self startLogin:^(NSError *result) {
        [self->loginProgress setHidden:YES];
        [self->loginProgress display];
        [self setStatusText:result.localizedDescription];
        if ([result.userInfo[ZKSoapFaultCodeKey] hasSuffix:@":LOGIN_MUST_USE_SECURITY_TOKEN"]) {
            NSInteger mc =[NSApp runModalForWindow:self.tokenWindow];
            [self.tokenWindow orderOut:self];
            if (NSModalResponseStop == mc) {
                [self login:sender];
            } else {
                [self->loginProgress setHidden:YES];
                [self->loginProgress display];
            }
        }
    } completeBlock:^(ZKSforceClient *client) {
        [self->loginProgress setHidden:YES];
        [self->loginProgress display];
        if (self.selectedCredential == nil || (![[[self.selectedCredential username] lowercaseString] isEqualToString:[self.username lowercaseString]])) {
            [self promptAndAddToKeychain];
            return;
        }
        else if (![[self.selectedCredential password] isEqualToString:self.password]) {
            [self promptAndUpdateKeychain];
            return;
        }
        [self closeLoginUi];
        [self.delegate loginController:self loginCompleted:self->sforce];
    }];
}

static NSString *OAUTH_CID = @"3MVG99OxTyEMCQ3hP1_9.Mh8dFxOk8gk6hPvwEgSzSxOs3HoHQhmqzBxALj8UBnhjzntUVXdcdZFXATXCdevs";

- (IBAction)startOAuthLogin:(id)sender {
    // for legacy reasons the server drop down says www.salesforce.com, and we manually map it to login.salesforce.com
    NSString *www = @"://www.salesforce.com";
    NSString *login = @"://login.salesforce.com";
    NSString *loginHost = [server stringByReplacingOccurrencesOfString:www withString:login options:NSCaseInsensitiveSearch range:NSMakeRange(0, server.length)];
    
    NSString *cb = @"soqlx://oauth/";
    // build the URL to the oauth page with our client_id & callback URL set.
    NSString *oauth = [NSString stringWithFormat:@"%@/services/oauth2/authorize?response_type=token&client_id=%@&redirect_uri=%@&state=%@",
                       loginHost,
                       [OAUTH_CID stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]],
                       [cb stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]],
                       self.controllerId];
    NSURL *url = [NSURL URLWithString:oauth];

    // ask the OS to open browser to the URL
    [[NSWorkspace sharedWorkspace] openURL:url];
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
    [self oauthCurrentUserInfoWithDowngrade:c
                                  failBlock:^(NSError *result) {
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
    [self openOAuthResponse:oauthCallbackUrl apiVersion:preferedApiVersion];
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
    Credential *cred = [self lastOAuthCredential];
    if (cred != nil) {
        [self loginWithOAuthToken:cred window:modalForWindow];
    } else {
        [self showLoginSheet:modalForWindow];
    }
}

- (void)loginWithOAuthToken:(Credential*)cred window:(NSWindow*)modalForWindow {
    [self showLoginSheet:modalForWindow];
    [self setStatusText:@"Logging in from saved OAuth token"];
    [loginProgress setHidden:NO];
    [loginProgress display];
    ZKFailWithErrorBlock failBlock = ^(NSError *err) {
        [self setStatusText:[NSString stringWithFormat:@"Refresh token no longer valid: %@", err.localizedDescription]];
        [self->loginProgress setHidden:YES];
        [self->loginProgress display];
    };

    ZKSforceClient *c = [self newClient:preferedApiVersion];
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

// Note this explictly filters out the oauth tokens, this are just password based credentials
- (NSArray *)credentials {
    if (credentials == nil) {
        // NSComboBox doesn't really bind to an object, its value is always the display string
        // regardless of how many you have with the same name, it doesn't bind the value to 
        // the underlying object (lame), so we filter out all the duplicate usernames
        NSArray *allCredentials = [Credential credentialsForServer:server];
        NSMutableArray * filtered = [NSMutableArray arrayWithCapacity:[allCredentials count]];
        NSMutableSet *usernames = [NSMutableSet set];
        for (Credential *c in allCredentials) {
            if (c.username.length == 0) continue;
            if (c.type != ctPassword) continue;
            NSString *lowerUsername = [c.username lowercaseString];
            if ([usernames containsObject:lowerUsername]) continue;
            [usernames addObject:lowerUsername];
            [filtered addObject:c];
        }
        credentials = filtered;
    }
    return credentials;
}

- (NSString *)server {
    return server;
}

- (void)setPasswordFromKeychain {
    // see if there's a matching credential and default the password if so
    for (Credential *c in [self credentials]) {
        if ([[c username] caseInsensitiveCompare:username] == NSOrderedSame) {
            [self setPassword:[c password]];
            [self setSelectedCredential:c];
            return;
        }
    }
    [self setSelectedCredential:nil];    
}

- (void)setServer:(NSString *)aServer {
    if ([server isEqualToString:aServer]) return;
    server = [aServer copy];
    credentials = nil;
    [self setSelectedCredential:nil];
    // we've changed server, so we need to recalc the password
    [self setPasswordFromKeychain];
}

- (NSString *)username {
    return username;
}

- (void)setUsername:(NSString *)aUsername {
    username = [aUsername copy];
    [self setPasswordFromKeychain];
}

- (IBAction)loginWithToken:(id)sender {
    self.password = [NSString stringWithFormat:@"%@%@", password, apiSecurityToken];
    [NSApp stopModal];
}

- (IBAction)cancelToken:(id)sender {
    [NSApp abortModal];
}

- (IBAction)showTokenHelp:(id)sender {
    NSURL *url = [NSURL URLWithString:@"https://help.salesforce.com/apex/HTViewHelpDoc?id=user_security_token.htm"];
    [[NSWorkspace sharedWorkspace] openURL:url];
}

- (BOOL)hasEnteredToken {
    return [apiSecurityToken length] > 0;
}

@end
