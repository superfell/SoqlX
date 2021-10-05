// Copyright (c) 2006-2015,2018,2021 Simon Fell
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

#import <Cocoa/Cocoa.h>
#import "LoginTargetController.h"
#import "LoginRowViewItem.h"

@class Credential;
@class ZKSforceClient;
@class ZKLoginController;

extern int DEFAULT_API_VERSION;

@protocol ZKLoginControllerDelegate <NSObject>
@required
-(void)loginController:(ZKLoginController *)controller loginCompleted:(ZKSforceClient *)client;
-(void)loginControllerLoginCancelled:(ZKLoginController *)controller;
@end

@interface ZKLoginController : NSObject<LoginTargetItemDelegate, LoginRowViewItemDelegate>
+(NSString*)appClientId;

-(void)showLoginSheet:(NSWindow *)modalForWindow;
-(void)loginWithOAuthToken:(Credential*)cred window:(NSWindow*)modalForWindow;
-(void)completeOAuthLogin:(NSURL *)oauthCallbackUrl;
-(IBAction)cancelLogin:(id)sender;

@property (assign) int preferedApiVersion;
@property (strong) NSString *controllerId;

@property (weak) NSObject<ZKLoginControllerDelegate> *delegate;

@end
