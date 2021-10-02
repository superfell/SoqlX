// Copyright (c) 2006-2013 Simon Fell
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
- (SecProtocolType)SecProtocolType {
    return [[[self scheme] lowercaseString] isEqualToString:@"http"] ? kSecProtocolTypeHTTP : kSecProtocolTypeHTTPS;
}
- (CFTypeRef)SecAttrProtocol {
    return [[[self scheme] lowercaseString] isEqualToString:@"http"] ? kSecAttrProtocolHTTP : kSecAttrProtocolHTTPS;
}

@end

@implementation Credential

// Server + Account Name is the key for keychain entries, so to deal with the case where we want to store
// separate password & refresh token for the same username/server, we need to mangle one of them to make the
// key unique. OAuth credentials will have @OAUTH appended to the username in the keychain. Usernames like
// simon@OAUTH are not valid in salesforce, it requires it to have a . in the host side, so there's no chance
// this can conflict. This is absracted away from users of this class, e.g. they'll see the de-mangled username
// and the relevant type flag. As there are existing keychain entries in the wild for passwords we won't mangle
// those at all.
NSString *OAUTH_TRAILER = @"@OAUTH";

+ (NSArray *)credentialsForServer:(NSURL *)url {
    NSString *server = url.host;
    
    NSMutableArray *results = [NSMutableArray array];
    NSArray *queryResults = nil;
    NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
                           (__bridge NSString*)kSecClassInternetPassword,   (__bridge NSString*)kSecClass,
                           (__bridge NSString*)kSecMatchLimitAll,           (__bridge NSString*)kSecMatchLimit,
                           kCFBooleanTrue,                                  (__bridge NSString*)kSecReturnRef,
                           kCFBooleanTrue,                                  (__bridge NSString*)kSecReturnAttributes,
                           server,                                          (__bridge NSString*)kSecAttrServer,
                           [url SecAttrProtocol],                           (__bridge NSString*)kSecAttrProtocol,
                           nil];

    OSStatus status = SecItemCopyMatching((CFDictionaryRef)query, (void *)&queryResults);
    if (status == noErr) {
        for (NSDictionary *item in queryResults) {
            NSString *username = item[(__bridge NSString*)kSecAttrAccount];
            SecKeychainItemRef itemRef = (__bridge SecKeychainItemRef)item[(__bridge NSString*)kSecValueRef];
            [results addObject:[Credential forServer:url username:username keychainItem:itemRef]];
        }
    } else if (status == errSecItemNotFound) {
        NSLog(@"No keychain items for server %@", server);
    } else {
        NSLog(@"SecItemCopyMatching returned error %ld for server %@", (long)status, server);
    }
    return results;
}

+ (id)forServer:(NSURL *)server username:(NSString *)un keychainItem:(SecKeychainItemRef)kcItem {
    return [[Credential alloc] initForServer:server username:un keychainItem:kcItem];
}

+ (id)createCredential:(NSURL *)url username:(NSString *)un password:(NSString *)pwd {
    NSString *server = [url host];
    SecKeychainItemRef itemRef;
    OSStatus status = SecKeychainAddInternetPassword (
                                NULL,
                                (UInt32)[server lengthOfBytesUsingEncoding:NSUTF8StringEncoding], 
                                [server UTF8String],
                                0, NULL,
                                (UInt32)[un lengthOfBytesUsingEncoding:NSUTF8StringEncoding],
                                [un UTF8String],
                                0, NULL,
                                0,
                                [url SecProtocolType],
                                kSecAuthenticationTypeDefault,
                                (UInt32)[pwd lengthOfBytesUsingEncoding:NSUTF8StringEncoding],
                                [pwd UTF8String],
                                &itemRef);
    if (status != noErr) {
        NSLog(@"SecKeychainAddInternetPassword returned error %ld", (long)status);
        return nil;
    }
    Credential *result = [Credential forServer:url username:un keychainItem:itemRef];
    CFRelease(itemRef);
    return result;
}

+ (id)createOAuthCredential:(NSURL *)protocolAndServer username:(NSString *)un refreshToken:(NSString *)tkn {
    NSString *mangledUsername = [un stringByAppendingString:OAUTH_TRAILER];
    Credential *c = [self createCredential:protocolAndServer username:mangledUsername password:tkn];
    c.comment = @"OAuth token";
    return c;
}

+ (id)createCredentialForServer:(NSURL *)protocolAndServer username:(NSString *)un password:(NSString *)pwd {
    return [self createCredential:protocolAndServer username:un password:pwd];
}

- (id)initForServer:(NSURL *)s username:(NSString *)un keychainItem:(SecKeychainItemRef)kcItem {
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
    return [NSString stringWithFormat:@"%@ at %@", self.username, server];
}

- (NSURL *)server {
    return server;
}

- (NSString *)username {
    if ([username hasSuffix:OAUTH_TRAILER]) {
        return [username substringToIndex:username.length-OAUTH_TRAILER.length];
    }
    return username;
}

- (CredentialType) type {
    return [username hasSuffix:OAUTH_TRAILER] ? ctRefreshToken : ctPassword;
}

-(NSString*)serverLabel {
    if ([server.host caseInsensitiveCompare:@"login.salesforce.com"] == NSOrderedSame) {
        return @"Production";
    }
    if ([server.host caseInsensitiveCompare:@"test.salesforce.com"] == NSOrderedSame) {
        return @"Sandbox";
    }
    return server.host;
}

- (NSString *)password {
    SecKeychainAttribute a[] = { { 0, 0, NULL } };
    SecKeychainAttributeList al = { 0, a };
    UInt32 length = 0;
    void *data = 0;
    NSString *pwd = nil;
    if (noErr == SecKeychainItemCopyContent(keychainItem, NULL, &al, &length, &data)) {
        pwd = [[NSString alloc] initWithBytes:data length:length encoding:NSUTF8StringEncoding];
        SecKeychainItemFreeContent(&al, data);
    }
    return pwd;
}

- (OSStatus)setKeychainAttribute:(SecItemAttr)attribute newValue:(NSString *)val newPassword:(NSString *)password {
    // Set up attribute vector (each attribute consists of {tag, length, pointer}):
    SecKeychainAttribute attrs[] = {
            { attribute, (UInt32)[val lengthOfBytesUsingEncoding:NSUTF8StringEncoding], (char *)[val UTF8String] } };
    const SecKeychainAttributeList attributes = { sizeof(attrs) / sizeof(attrs[0]),  attrs };
    OSStatus status = SecKeychainItemModifyAttributesAndData (
                                    keychainItem,   // the item reference
                                    &attributes,    // no change to attributes
                                    (UInt32)[password lengthOfBytesUsingEncoding:NSUTF8StringEncoding],
                                    [password UTF8String] );
    if (status != noErr) {
        NSLog(@"SecKeychainItemModifyAttributesAndData returned %ld", (long)status);
    }
    return status;
}

- (OSStatus)updatePassword:(NSString *)newPassword {
    OSStatus status = [self setKeychainAttribute:kSecAccountItemAttr newValue:username newPassword:newPassword];
    return status;
}

- (NSString *)stringAttribute:(int)attributeToRead {
    SecKeychainAttribute a[] = { { attributeToRead, 0, NULL } };
    SecKeychainAttributeList al = { 1, a };
    NSString *comment = nil;
    if (noErr == SecKeychainItemCopyContent(keychainItem, NULL, &al, nil, nil)) {
        comment = [[NSString alloc] initWithBytes:a[0].data length:a[0].length encoding:NSUTF8StringEncoding];
    }
    SecKeychainItemFreeContent(&al, nil);
    return comment;
}

- (NSString *)comment {
    return [self stringAttribute:kSecCommentItemAttr];
}

- (void)setComment:(NSString *)newComment {
    NSAssert(noErr == [self setKeychainAttribute:kSecCommentItemAttr
                                        newValue:newComment
                                     newPassword:nil], @"Unable to set comment attribute in keychain entry");
}

@end
