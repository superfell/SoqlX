// Copyright (c) 2006-2008,2013,2021 Simon Fell
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
#include <Security/Security.h>

@interface Credential : NSObject {
    NSURL               *server;
    NSString            *username;
    SecKeychainItemRef   keychainItem;
}

+ (NSArray<Credential*> *)credentials;
+ (NSArray<Credential*> *)credentialsInMruOrder;

+ (instancetype)createCredential:(NSURL *)server username:(NSString *)un refreshToken:(NSString *)tkn;

- (instancetype)initForServer:(NSURL *)server username:(NSString *)un keychainItem:(SecKeychainItemRef)kcItem NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property (readonly) NSURL    *server;
@property (readonly) NSString *username;
@property (readonly) NSString *token;

-(OSStatus)updateToken:(NSString *)token;
-(OSStatus)deleteEntry;

@end

@interface NSURL (ZKKeychain)
@property (readonly) NSString *friendlyHostLabel;
@property (readonly) BOOL isStandardEndpoint;
@end
