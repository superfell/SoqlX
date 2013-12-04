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
                           kSecClassInternetPassword, kSecClass,
                           kSecMatchLimitAll, kSecMatchLimit,
                           kCFBooleanTrue, kSecReturnRef,
                           kCFBooleanTrue, kSecReturnAttributes,
                           server, kSecAttrServer,
                           [url SecAttrProtocol], kSecAttrProtocol,
                           nil];

    OSStatus status = SecItemCopyMatching((CFDictionaryRef)query, (CFTypeRef *)&queryResults);
	if (status == noErr) {
        for (NSDictionary *item in queryResults) {
            NSString *username = [item objectForKey:kSecAttrAccount];
            SecKeychainItemRef itemRef = (SecKeychainItemRef)[item objectForKey:kSecValueRef];
            [results addObject:[Credential forServer:protocolAndServer username:username keychainItem:itemRef]];
        }
        CFRelease(queryResults);
	} else {
		NSLog(@"SecItemCopyMatching returned error %ld", (long)status);
	}
	return results;
}

+ (NSArray *)sortedCredentialsForServer:(NSString *)protocolAndServer {
	NSArray *credentials = [Credential credentialsForServer:protocolAndServer];
	NSSortDescriptor *sortDesc = [[NSSortDescriptor alloc] initWithKey:@"username" ascending:YES];
	NSArray *sorted = [credentials sortedArrayUsingDescriptors:[NSArray arrayWithObject:sortDesc]];
	[sortDesc release];
	return sorted;
}

+ (id)forServer:(NSString *)server username:(NSString *)un keychainItem:(SecKeychainItemRef)kcItem {
	return [[[Credential alloc] initForServer:server username:un keychainItem:kcItem] autorelease];
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
	[server release];
	[username release];
	CFRelease(keychainItem);
	[super dealloc];
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
		pwd = [[[NSString alloc] initWithBytes:data length:length encoding:NSUTF8StringEncoding] autorelease];
        SecKeychainItemFreeContent(&al, data);
	}
	return pwd;
}

- (void)removeFromKeychain {
	SecKeychainItemDelete(keychainItem);
}

BOOL checkAccessToAcl(SecACLRef acl, NSData *thisAppHash) {
	NSArray *apps;
	NSString *desc;
	SecKeychainPromptSelector ps;
	OSStatus err = SecACLCopyContents(acl, (CFArrayRef *)&apps, (CFStringRef *)&desc, &ps);
	BOOL res = NO;
	if (err == noErr) {
		if (apps == nil) {
			res = YES;	// from the docs, if the app list is null, anyone can access the entry
		} else {
			// see if we're in the list of apps
			NSData *aData;
			SecTrustedApplicationRef a;
			NSEnumerator *e = [apps objectEnumerator];
			while ((a = (SecTrustedApplicationRef)[e nextObject])) {
				SecTrustedApplicationCopyData(a, (CFDataRef *)&aData);
				if ([aData isEqualToData:thisAppHash]) res = YES;
				CFRelease(aData);
				if (res) break;
			}
			CFRelease(apps);
		}
		CFRelease(desc);
	} else {
		NSLog(@"SecACLCopySimpleContents failed with error %ld", (long)err);
	}
	return res;
}

- (BOOL)canReadPasswordWithoutPrompt {
	SecTrustedApplicationRef app;
	OSStatus err = SecTrustedApplicationCreateFromPath(NULL, &app);
	if (noErr != err) {
		NSLog(@"SecTrustedApplicationCreateFromPath failed with error %ld", (long)err);
		return NO;
	}
	NSData *thisAppHash;
	BOOL res = NO;
	err = SecTrustedApplicationCopyData(app, (CFDataRef *)&thisAppHash);
	if (err == noErr) {
		SecAccessRef access;
		err = SecKeychainItemCopyAccess(keychainItem, &access);
		if (noErr == err) {
            NSArray *acls = (NSArray *)SecAccessCopyMatchingACLList(access, kSecACLAuthorizationDecrypt);
            if (acls != NULL) {
                SecACLRef acl;
                NSEnumerator *e = [acls objectEnumerator];
                while ((acl = (SecACLRef)[e nextObject])) {
                    res = checkAccessToAcl(acl, thisAppHash);
                    if (res) break;
                }
                CFRelease(acls);
            }
			CFRelease(access);
		} else {
			NSLog(@"SecKeychainItemCopyAccess failed with error %ld", (long)err);
		}
		CFRelease(thisAppHash);
	} else {
		NSLog(@"SecTrustedApplicationCopyData failed with error %ld", (long)err);
	}
	CFRelease(app);
	return res;
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
		[server release];
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
		[username autorelease];
		username = [newUsername copy];
	}	
	return status;
}

- (NSString *)stringAttribute:(int)attributeToRead {
	SecKeychainAttribute a[] = { { attributeToRead, 0, NULL } };
	SecKeychainAttributeList al = { 1, a };
	NSString *comment = nil;
	if (noErr == SecKeychainItemCopyContent(keychainItem, NULL, &al, nil, nil)) {
        comment = [[[NSString alloc] initWithBytes:a[0].data length:a[0].length encoding:NSUTF8StringEncoding] autorelease];
	}
	SecKeychainItemFreeContent(&al, nil);
	return comment;
}

- (NSString *)comment {
	return [self stringAttribute:kSecCommentItemAttr];
}

- (NSString *)creator {
	return [self stringAttribute:kSecCreatorItemAttr];
}

- (void)setComment:(NSString *)newComment {
	NSAssert(noErr == [self setKeychainAttribute:kSecCommentItemAttr newValue:newComment newPassword:nil], @"Unable to set comment attribute in keychain entry");
}

- (void)setCreator:(NSString *)newCreator {
	NSAssert(noErr == [self setKeychainAttribute:kSecCreatorItemAttr newValue:newCreator newPassword:nil], @"Unable to set creator attribute in keychain entry"); 
}

@end
