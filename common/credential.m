// Copyright (c) 2006-2013,2021 Simon Fell
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

#import "credential.h"
#import "Defaults.h"

@implementation NSURL (ZKKeychain)
-(NSString*)friendlyHostLabel {
    if ([self.host caseInsensitiveCompare:@"login.salesforce.com"] == NSOrderedSame) {
        return @"Production";
    }
    if ([self.host caseInsensitiveCompare:@"test.salesforce.com"] == NSOrderedSame) {
        return @"Sandbox";
    }
    return self.host;
}
-(BOOL)isStandardEndpoint {
    return  ([self.host caseInsensitiveCompare:@"login.salesforce.com"] == NSOrderedSame) ||
            ([self.host caseInsensitiveCompare:@"test.salesforce.com"] == NSOrderedSame);
}
@end

@implementation Credential

NSString *AUTH_SVC_NAME = @"com.pocketsoap.osx.soqlx.auth";

+(NSArray<Credential*> *)credentials {
    NSMutableArray *results = [NSMutableArray array];
    NSArray *queryResults = nil;
    NSDictionary *query = @{
        (__bridge NSString*)kSecClass:              (__bridge NSString*)kSecClassGenericPassword,
        (__bridge NSString*)kSecAttrLabel:          AUTH_SVC_NAME,
        (__bridge NSString*)kSecMatchLimit:         (__bridge NSString*)kSecMatchLimitAll,
        (__bridge NSString*)kSecReturnRef:          @TRUE,
        (__bridge NSString*)kSecReturnAttributes:   @TRUE,
    };
    OSStatus status = SecItemCopyMatching((CFDictionaryRef)query, (void *)&queryResults);
    if (status == noErr) {
        for (NSDictionary *item in queryResults) {
            NSString *username = item[(__bridge NSString*)kSecAttrAccount];
            NSString *host = item[(__bridge NSString*)kSecAttrService];
            NSURL *url = [NSURL URLWithString:[@"https://" stringByAppendingString:host]];
            SecKeychainItemRef itemRef = (__bridge SecKeychainItemRef)item[(__bridge NSString*)kSecValueRef];
            [results addObject:[[Credential alloc] initForServer:url username:username keychainItem:itemRef]];
        }
    } else if (status == errSecItemNotFound) {
        NSLog(@"No keychain items found");
    } else {
        NSLog(@"SecItemCopyMatching returned error %ld", (long)status);
    }
    return results;
}

+(id)createCredential:(NSURL *)url username:(NSString *)un refreshToken:(NSString *)tkn {
    NSDictionary* item = @{
        (__bridge NSString*)kSecClass:          (__bridge NSString*)kSecClassGenericPassword,
        (__bridge NSString*)kSecAttrService:    [url host],
        (__bridge NSString*)kSecAttrAccount:    un,
        (__bridge NSString*)kSecAttrLabel:      AUTH_SVC_NAME,
        (__bridge NSString*)kSecAttrDescription:@"Refresh Token",
        (__bridge NSString*)kSecValueData:      [tkn dataUsingEncoding:NSUTF8StringEncoding],
        (__bridge NSString*)kSecReturnRef:      @TRUE,
    };
    SecKeychainItemRef itemRef;
    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)item, (void*) &itemRef);
    if (status != noErr) {
        NSLog(@"SecItemAdd returned error %ld", (long)status);
        return nil;
    }
    NSURL *authUrl = [NSURL URLWithString:[@"https://" stringByAppendingString:url.host]];
    Credential *result = [[Credential alloc] initForServer:authUrl username:un keychainItem:itemRef];
    CFRelease(itemRef);
    return result;
}

-(id)initForServer:(NSURL *)s username:(NSString *)un keychainItem:(SecKeychainItemRef)kcItem {
    self = [super init];
    server = [s copy];
    username = [un copy];
    keychainItem = kcItem;
    CFRetain(keychainItem);
    return self;
}

- (void)dealloc {
    CFRelease(keychainItem);
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ at %@", username, server];
}

- (NSURL *)server {
    return server;
}

- (NSString *)username {
    return username;
}

- (NSString *)token {
    UInt32 length = 0;
    void *data = 0;
    NSString *pwd = nil;
    if (noErr == SecKeychainItemCopyContent(keychainItem, NULL, NULL, &length, &data)) {
        pwd = [[NSString alloc] initWithBytes:data length:length encoding:NSUTF8StringEncoding];
        SecKeychainItemFreeContent(NULL, data);
    }
    return pwd;
}

-(OSStatus)updateToken:(NSString *)newToken {
    OSStatus status = SecKeychainItemModifyAttributesAndData (
                                    keychainItem,   // the item reference
                                    NULL,           // no change to attributes
                                    (UInt32)[newToken lengthOfBytesUsingEncoding:NSUTF8StringEncoding],
                                    [newToken UTF8String] );
    if (status != noErr) {
        NSLog(@"SecKeychainItemModifyAttributesAndData returned %ld", (long)status);
    }
    return status;
}

@end
