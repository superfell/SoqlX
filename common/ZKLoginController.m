// Copyright (c) 2006-2012 Simon Fell
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
#import "zkSforceClient.h"
#import "zkSoapException.h"

@implementation ZKLoginController

@synthesize clientId, urlOfNewServer, statusText, password, preferedApiVersion;

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

- (id)init {
	self = [super init];
	server = [[[NSUserDefaults standardUserDefaults] objectForKey:@"server"] copy];
	[self setUsername:[[NSUserDefaults standardUserDefaults] objectForKey:login_lastUsernameKey]];
	preferedApiVersion = 25;
	return self;
}

- (void)setImage:(NSString *)name onButton:(NSButton *)b {
	NSString *imgFile = [[NSBundle mainBundle] pathForResource:name ofType:@"png"];
	NSImage *img = [[[NSImage alloc] initWithContentsOfFile:imgFile] autorelease];
	[b setImage:img];
}

- (void)awakeFromNib {
	[loginProgress setUsesThreadedAnimation:YES];
	[loginProgress setHidden:YES];
	[loginProgress setDoubleValue:22.0];
}

- (void)dealloc {
	[username release];
	[password release];
	[server release];
	[clientId release];
	[credentials release];
	[selectedCredential release];
	[sforce release];
	[urlOfNewServer release];
	[super dealloc];
}

- (void)loadNib {
	[NSBundle loadNibNamed:@"Login" owner:self];	
}

- (void)setClientIdFromInfoPlist {
	NSDictionary *plist = [[NSBundle mainBundle] infoDictionary];
	NSString *cid = [NSString stringWithFormat:@"%@/%@", [plist objectForKey:@"CFBundleName"], [plist objectForKey:@"CFBundleVersion"]];
	[self setClientId:cid];
}

- (void)endModalWindow:(id)sforce {
	[NSApp stopModal];
}

- (ZKSforceClient *)showModalLoginWindow:(id)sender {
	return [self showModalLoginWindow:sender submitIfHaveCredentials:NO];
}

- (ZKSforceClient *)showModalLoginWindow:(id)sender submitIfHaveCredentials:(BOOL)autoSubmit {
	[self loadNib];
	target = self;
	selector = @selector(endModalWindow:);
	modalWindow = nil;
	if (autoSubmit && [password length] > 0 && [username length] > 0) {
		[self login:sender];
		if ([statusText length] == 0) return sforce;
	}
	[NSApp runModalForWindow:window];
	[window close];
	return [sforce loggedIn] ? sforce : nil;
}

- (void)showLoginWindow:(id)sender target:(id)t selector:(SEL)s {
	[self loadNib];
	target = t;
	selector = s;
	modalWindow = nil;
	[window makeKeyAndOrderFront:sender];
}

- (void)showLoginSheet:(NSWindow *)modalForWindow target:(id)t selector:(SEL)s {
	[self loadNib];
	target = t;
	selector = s;
	modalWindow = modalForWindow;
	[NSApp beginSheet:window modalForWindow:modalForWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
}

- (void)restoreLoginWindow:(NSWindow *)w returnCode:(int)rc contextInfo:(id)ctx {
	if (modalWindow != nil) {
		[w orderOut:self];
		[NSApp beginSheet:window modalForWindow:modalWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
	}
}

- (BOOL)canDeleteServer {
	return ([server caseInsensitiveCompare:prod] != NSOrderedSame) && ([server caseInsensitiveCompare:test] != NSOrderedSame);
}

- (IBAction)showAddNewServer:(id)sender {
	[self setUrlOfNewServer:@"https://"];
	if (modalWindow != nil) {
		[NSApp endSheet:window];
		[window orderOut:sender];
	}
	[NSApp beginSheet:newUrlWindow
       modalForWindow:modalWindow == nil ? window : modalWindow
        modalDelegate:self
       didEndSelector:@selector(restoreLoginWindow:returnCode:contextInfo:)
          contextInfo:nil];
}

- (IBAction)closeAddNewServer:(id)sender {
	[NSApp endSheet:newUrlWindow];	
	[newUrlWindow orderOut:sender];
}

- (IBAction)deleteServer:(id)sender {
	if (![self canDeleteServer]) return;
	NSArray *servers = [[NSUserDefaults standardUserDefaults] objectForKey:@"servers"];
	NSMutableArray *newServers = [NSMutableArray arrayWithCapacity:[servers count]];
	NSString *s;
	NSEnumerator *e = [servers objectEnumerator];
	while (s = [e nextObject]) {
		if ([s caseInsensitiveCompare:server] == NSOrderedSame) continue;
		[newServers addObject:s];
	}
	[[NSUserDefaults standardUserDefaults] setObject:newServers forKey:@"servers"];
	[self setServer:prod];
}

- (IBAction)addNewServer:(id)sender {
	NSString *new = [self urlOfNewServer];
	if (![new isEqualToString:@"https://"]) {
		NSArray *servers = [[NSUserDefaults standardUserDefaults] objectForKey:@"servers"];
		if (![servers containsObject:new]) {
			NSMutableArray *newServers = [NSMutableArray array];
			[newServers addObjectsFromArray:servers];
			[newServers addObject:new];
			[[NSUserDefaults standardUserDefaults] setObject:newServers forKey:@"servers"];
		}
		[self setServer:new];
		[self closeAddNewServer:sender];
	}
}

- (IBAction)cancelLogin:(id)sender {
	if (target == self) {
		[NSApp stopModal];
	} else if (modalWindow != nil) {
		[NSApp endSheet:window];
		[window orderOut:sender];
	} else {
		[window close];
	}
}

- (Credential *)selectedCredential {
	return selectedCredential;
}

- (void)setSelectedCredential:(Credential *)aValue {
	Credential *oldSelectedCredential = selectedCredential;
	selectedCredential = [aValue retain];
	[oldSelectedCredential release];
}

- (void)showAlertSheetWithMessageText:(NSString *)message 
			defaultButton:(NSString *)defaultButton 
			altButton:(NSString *)altButton 
			otherButton:(NSString *)otherButton 
			additionalText:(NSString *)additionalText 
			didEndSelector:(SEL)didEndSelector
			contextInfo:(id)context {
	NSAlert * a = [NSAlert alertWithMessageText:message defaultButton:defaultButton alternateButton:altButton otherButton:otherButton informativeTextWithFormat:additionalText];
	NSWindow *wndForAlertSheet = modalWindow == nil ? window : modalWindow;
	if (modalWindow != nil) {
		[NSApp endSheet:window];
		[window orderOut:self];
	}
	[a beginSheetModalForWindow:(NSWindow *)wndForAlertSheet modalDelegate:self didEndSelector:didEndSelector contextInfo:context];
}

- (void)updateKeychain:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo {
//	NSLog(@"updateKeychain rc=%d", returnCode);
	if (returnCode == NSAlertDefaultReturn)
		[[self selectedCredential] update:username password:password];
	[[alert window] orderOut:self];
	[self cancelLogin:self];
	[target performSelector:selector withObject:sforce];	
}

- (void)createKeychain:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo {
//	NSLog(@"createKeychain rc=%d", returnCode);
	if (returnCode == NSAlertDefaultReturn) 
		[Credential createCredentialForServer:server username:username password:password];
	[[alert window] orderOut:self];
	[self cancelLogin:self];
	[target performSelector:selector withObject:sforce];	
}

- (void)promptAndAddToKeychain {
	[self showAlertSheetWithMessageText:@"Crete Keychain entry with new username & password?" 
				defaultButton:@"Create Keychain Entry" 
				altButton:@"No thanks" 
				otherButton:nil 
				additionalText:@"" 
				didEndSelector:@selector(createKeychain:returnCode:contextInfo:) 
				contextInfo:nil];
}

- (void)promptAndUpdateKeychain {
	[self showAlertSheetWithMessageText:@"Update Keychain entry with new password?" 
				defaultButton:@"Update Keychain" 
				altButton:@"No thanks" 
				otherButton:nil 
				additionalText:@"" 
				didEndSelector:@selector(updateKeychain:returnCode:contextInfo:) 
				contextInfo:nil];
}

- (ZKSforceClient *)performLogin:(ZKSoapException **)error withApiVersion:(int)version {
	[sforce release];
	sforce = [[ZKSforceClient alloc] init];
	[sforce setLoginProtocolAndHost:server andVersion:version];	
	if ([clientId length] > 0)
		[sforce setClientId:clientId];
	@try {
		[sforce login:username password:password];
		[[NSUserDefaults standardUserDefaults] setObject:server forKey:@"server"];
		[[NSUserDefaults standardUserDefaults] setObject:username forKey:login_lastUsernameKey];
	}
	@catch (ZKSoapException *ex) {
		if ([[ex reason] hasPrefix:@"UNSUPPORTED_API_VERSION:"]) {
			NSLog(@"Login failed with %@ on API Version %d, retrying with version %d", [ex reason], version, version-1);
			return [self performLogin:error withApiVersion:version-1];
		}
		if (error != nil) *error = ex;
		return nil;
	}
	return sforce;
}

- (ZKSforceClient *)performLogin:(ZKSoapException **)error {
	return [self performLogin:error withApiVersion:preferedApiVersion];
}

- (IBAction)login:(id)sender {
	[self setStatusText:nil];
	[loginProgress setHidden:NO];
	[loginProgress display];
	@try {
		ZKSoapException *ex = nil;
		[self performLogin:&ex];
		if (ex != nil) {
			[self setStatusText:[ex reason]];
			return;
		} 
		if (selectedCredential == nil || (![[[selectedCredential username] lowercaseString] isEqualToString:[username lowercaseString]])) {
			[self promptAndAddToKeychain];
			return;
		}
		else if (![[selectedCredential password] isEqualToString:password]) {
			[self promptAndUpdateKeychain];
			return;
		}
		[self cancelLogin:sender];
		[target performSelector:selector withObject:sforce];
	}
	@finally {		
		[loginProgress setHidden:YES];
		[loginProgress display];
	}
}

- (NSArray *)credentials {
	if (credentials == nil) {
		// NSComboBox doesn't really bind to an object, its value is always the display string
		// regardless of how many you have with the same name, it doesn't bind the value to 
		// the underlying object (lame), so we filter out all the duplicate usernames
		NSArray *allCredentials = [Credential credentialsForServer:server];
		NSMutableArray * filtered = [NSMutableArray arrayWithCapacity:[allCredentials count]];
		NSMutableSet *usernames = [NSMutableSet set];
		Credential *c;
		NSEnumerator *e = [allCredentials objectEnumerator];
		while (c = [e nextObject]) {
			if ([usernames containsObject:[[c username] lowercaseString]]) continue;
			[usernames addObject:[[c username] lowercaseString]];
			[filtered addObject:c];
		}
		credentials = [filtered retain];
	}
	return credentials;
}

- (NSString *)server {
	return server;
}

- (void)setPasswordFromKeychain {
	// see if there's a matching credential and default the password if so
	Credential *c;
	NSEnumerator *e = [[self credentials] objectEnumerator];
	while (c = [e nextObject]) {
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
	[server release];
	server = [aServer copy];
	[credentials release];
	credentials = nil;
	[self setSelectedCredential:nil];
	// we've changed server, so we need to recalc the password
	[self setPasswordFromKeychain];
}

- (NSString *)username {
	return [[username retain] autorelease];
}

- (void)setUsername:(NSString *)aUsername {
	[username autorelease];
	username = [aUsername copy];
	[self setPasswordFromKeychain];
}

@end
