// Copyright (c) 2012,2018,2019 Simon Fell
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

#import <Foundation/Foundation.h>
#import <Sparkle/Sparkle.h>

@class Explorer;
@class ZKSforceClient;
@class SoqlXWindowController;
@class OAuthMenuManager;

@interface AppDelegate : NSObject<NSApplicationDelegate, SUUpdaterDelegate>

- (IBAction)launchHelp:(id)sender;
- (IBAction)openNewWindow:(id)sender;
- (IBAction)showFontPrefs:(id)sender;
- (void)openNewWindowForOAuthCredential:(id)sender;

@property (strong) NSMutableArray<SoqlXWindowController*>* windowControllers;
@property (strong) NSString *editFontLabel;
@property (strong) NSFont *editFont;
@property (assign) BOOL isOpeningFromUrl;

@end

@interface SoqlXWindowController : NSWindowController

-(instancetype)initWithWindowControllers:(NSMutableArray *)controllers;

-(void)showWindowForClient:(ZKSforceClient*)client;
-(void)closeLoginPanelIfOpen:(id)sender;
-(void)completeOAuthLogin:(NSURL*)url;

@property (strong) IBOutlet Explorer *explorer;
@property (strong) NSMutableArray<SoqlXWindowController*> *controllers;
@property (readonly) NSString *controllerId;

@end
