// Copyright (c) 2006-2015 Simon Fell
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

// LoginController and Login.nib make a reusable login window that support
// the keychain, multiple servers, and differing ways to open the window
#import <Cocoa/Cocoa.h>

@class Credential;
@class ZKSforceClient;
@class ZKSoapException;
@class ZKLoginController;

@protocol ZKLoginControllerDelegate <NSObject>
@optional
-(void)loginControllerLoginCancelled:(ZKLoginController *)controller;
-(void)loginController:(ZKLoginController *)controller loginCompleted:(ZKSforceClient *)client;
-(void)loginController:(ZKLoginController *)controller serverUrlAdded:(NSURL *)url;
-(void)loginController:(ZKLoginController *)controller serverUrlRemoved:(NSURL *)url;
@end

@interface ZKLoginController : NSObject {
	NSString 		*username;
	NSString 		*password;
	NSString 		*server;
	NSString 		*clientId;
	NSArray  		*credentials;
	Credential 		*selectedCredential;
	ZKSforceClient 	*sforce;
	NSString		*urlOfNewServer;
	NSString		*statusText;
	int				preferedApiVersion;
	
	NSWindow 			*modalWindow;
	id					target;
	SEL					selector;	
	IBOutlet NSWindow 	*window;
	IBOutlet NSButton 	*addButton;
	IBOutlet NSButton	*delButton;
	IBOutlet NSWindow	*newUrlWindow;
	IBOutlet NSProgressIndicator *loginProgress;
    
    NSWindow        *tokenWindow;
    NSString        *apiSecurityToken;
    
    NSObject<ZKLoginControllerDelegate> *delegate;
    NSArray *nibTopLevelObjects;
}

- (ZKSforceClient *)showModalLoginWindow:(id)sender;
- (ZKSforceClient *)showModalLoginWindow:(id)sender submitIfHaveCredentials:(BOOL)autoSubmit;

- (void)showLoginWindow:(id)sender target:(id)target selector:(SEL)selector;
- (void)showLoginSheet:(NSWindow *)modalForWindow target:(id)target selector:(SEL)selector;

- (IBAction)cancelLogin:(id)sender;
- (IBAction)login:(id)sender;
- (IBAction)showAddNewServer:(id)sender;
- (IBAction)closeAddNewServer:(id)sender;
- (IBAction)addNewServer:(id)sender;
- (IBAction)deleteServer:(id)sender;

- (IBAction)loginWithToken:(id)sender;
- (IBAction)cancelToken:(id)sender;
- (IBAction)showTokenHelp:(id)sender;
- (BOOL)hasEnteredToken;
@property (retain) IBOutlet NSWindow *tokenWindow;
@property (retain) NSString *apiSecurityToken;

@property (retain) NSString *username;
@property (retain) NSString *password;
@property (retain) NSString *server;
@property (retain) NSString *urlOfNewServer;
@property (retain) NSString *statusText;
@property (retain) NSString *clientId;
@property (assign) int preferedApiVersion;
@property (assign) NSObject<ZKLoginControllerDelegate> *delegate;

- (NSArray *)credentials;
- (BOOL)canDeleteServer;
- (void)setClientIdFromInfoPlist;
- (ZKSforceClient *)performLogin:(ZKSoapException **)error;


@end
