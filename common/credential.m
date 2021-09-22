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

@implementation NSURL (ZKKeychain)
- (SecProtocolType)SecProtocolType {
    return [[[self scheme] lowercaseString] isEqualToString:@"http"] ? kSecProtocolTypeHTTP : kSecProtocolTypeHTTPS;
}
- (CFTypeRef)SecAttrProtocol {
    return [[[self scheme] lowercaseString] isEqualToString:@"http"] ? kSecAttrProtocolHTTP : kSecAttrProtocolHTTPS;
}

@end

@implementation Credential

+ (NSArray *)credentialsForServer:(NSString *)protocolAndServer {
    NSURL *url = [NSURL URLWithString:protocolAndServer];
    NSString *server = [url host];
    
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
            [results addObject:[Credential forServer:protocolAndServer username:username keychainItem:itemRef]];
        }
    } else {
        NSLog(@"SecItemCopyMatching returned error %ld", (long)status);
    }
    return results;
}

+ (NSArray *)sortedCredentialsForServer:(NSString *)protocolAndServer {
    NSArray *credentials = [Credential credentialsForServer:protocolAndServer];
    NSSortDescriptor *sortDesc = [[NSSortDescriptor alloc] initWithKey:@"username" ascending:YES];
    NSArray *sorted = [credentials sortedArrayUsingDescriptors:[NSArray arrayWithObject:sortDesc]];
    return sorted;
}

+ (id)forServer:(NSString *)server username:(NSString *)un keychainItem:(SecKeychainItemRef)kcItem {
    return [[Credential alloc] initForServer:server username:un keychainItem:kcItem];
}

+ (id)createCredentialForServer:(NSString *)protocolAndServer username:(NSString *)un password:(NSString *)pwd {
    NSURL *url = [NSURL URLWithString:protocolAndServer];
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
    Credential *result = [Credential forServer:protocolAndServer username:un keychainItem:itemRef];
    CFRelease(itemRef);
    return result;
}

- (id)initForServer:(NSString *)s username:(NSString *)un keychainItem:(SecKeychainItemRef)kcItem {
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

- (NSString *)server {
    return server;
}

- (NSString *)username {
    return username;
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
    if (status != noErr) 
        NSLog(@"SecKeychainItemModifyAttributesAndData returned %ld", (long)status);
    return status;
}

- (void)setServer:(NSString *)protocolAndServer {
    NSURL *url = [NSURL URLWithString:protocolAndServer];
    NSString *host = [url host];
    SecProtocolType protocol = [url SecProtocolType];
    
    // Set up attribute vector (each attribute consists of {tag, length, pointer}):
    SecKeychainAttribute attrs[] = { {kSecServerItemAttr, (UInt32)[host lengthOfBytesUsingEncoding:NSUTF8StringEncoding], (char *)[host UTF8String] }, 
                                       {kSecProtocolItemAttr, sizeof(SecProtocolType), &protocol } };
                                
    const SecKeychainAttributeList attributes = { sizeof(attrs) / sizeof(attrs[0]),  attrs };
    OSStatus status = SecKeychainItemModifyAttributesAndData (
                            keychainItem,   // the item reference
                            &attributes,    // no change to attributes
                            0,
                            nil );
    if (status == noErr) {
        server = [protocolAndServer copy];
    }
    NSAssert(noErr == status, @"Unable to set server name in keychain entry");
}

- (void)setUsername:(NSString *)newUsername {
    NSAssert(noErr == [self update:newUsername password:nil], @"Unable to set username attribute in keychain entry");
}

- (void)setPassword:(NSString *)newPassword {
    NSAssert(noErr == [self update:username password:newPassword], @"Unable to set password attribute in keychain entry");
}

- (OSStatus)update:(NSString *)newUsername password:(NSString *)newPassword {
    OSStatus status = [self setKeychainAttribute:kSecAccountItemAttr newValue:newUsername newPassword:newPassword];
    if (status == noErr)  {
        username = [newUsername copy];
    }    
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
}

@end
