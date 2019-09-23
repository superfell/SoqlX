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


int DEFAULT_API_VERSION = 47;


@interface ZKLoginController ()
@property (strong) Credential *selectedCredential;
-(void)closeLoginUi;
@end

@implementation ZKLoginController

@synthesize clientId, urlOfNewServer, statusText, password, preferedApiVersion, delegate, selectedCredential;
@synthesize tokenWindow, apiSecurityToken;

static NSString *login_lastUsernameKey = @"login_lastUserName";
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
                         [[self selectedCredential] update:self->username password:self->password];
                    }
                    [self closeLoginUi];
                    [self.delegate loginController:self loginCompleted:self->sforce];
                }];
}

- (void)startLoginWithApiVersion:(int)version
                       failBlock:(ZKFailWithErrorBlock)failBlock
                   completeBlock:(void(^)(ZKSforceClient *client))completeBlock {
    
    ZKSforceClient *newClient = [[ZKSforceClient alloc] init];
    sforce = newClient;
    [newClient setLoginProtocolAndHost:server andVersion:version];
    if ([clientId length] > 0) {
        [newClient setClientId:clientId];
    }
    [newClient login:username password:password failBlock:^(NSError *result) {
        if ([result.userInfo[ZKSoapFaultCodeKey] hasPrefix:@"UNSUPPORTED_API_VERSION"]) {
            NSLog(@"Login failed with %@ on API Version %d, retrying with version %d", result, version, version-1);
            [self startLoginWithApiVersion:version-1 failBlock:failBlock completeBlock:completeBlock];
        } else {
            failBlock(result);
        }
    } completeBlock:^(ZKLoginResult *result) {
        [[NSUserDefaults standardUserDefaults] setObject:self.server forKey:@"server"];
        [[NSUserDefaults standardUserDefaults] setObject:self.username forKey:login_lastUsernameKey];
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
        [self setStatusText:result.localizedDescription];
        if ([result.userInfo[ZKSoapFaultCodeKey] hasPrefix:@"LOGIN_MUST_USE_SECURITY_TOKEN"]) {
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

- (NSArray *)credentials {
    if (credentials == nil) {
        // NSComboBox doesn't really bind to an object, its value is always the display string
        // regardless of how many you have with the same name, it doesn't bind the value to 
        // the underlying object (lame), so we filter out all the duplicate usernames
        NSArray *allCredentials = [Credential credentialsForServer:server];
        NSMutableArray * filtered = [NSMutableArray arrayWithCapacity:[allCredentials count]];
        NSMutableSet *usernames = [NSMutableSet set];
        for (Credential *c in allCredentials) {
            if ([[c username] length] == 0) continue;
            NSString *lowerUsername = [[c username] lowercaseString];
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
