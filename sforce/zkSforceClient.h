// Copyright (c) 2006 Simon Fell
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


#import "zkBaseClient.h"

@class ZKUserInfo;
@class ZKDescribeSObject;
@class ZKQueryResult;
@class ZKLoginResult;

// This is the primary entry point into the library, you'd create one of these
// call login, then use it to make other API calls. Your session is automatically
// kept alive, and login will be called again for you if needed.
//////////////////////////////////////////////////////////////////////////////////////
@interface ZKSforceClient : ZKBaseClient <NSCopying> {
	NSString	*authEndpointUrl;
	NSString	*username;
	NSString	*password;
	NSString	*clientId;	
	NSString	*sessionId;
	NSDate		*sessionExpiresAt;
	BOOL		updateMru;
	ZKUserInfo	*userInfo;
	BOOL		cacheDescribes;
	NSMutableDictionary	*describes;
	int			preferedApiVersion;
}

// configuration for where to connect to and what api version to use
//////////////////////////////////////////////////////////////////////////////////////
// Set the default API version to connect to. (defaults to v19.0)
// login will automatically detect if the endpoint doesn't have this
// version and automatically retry on a lower API version.
-(void)setPreferedApiVersion:(int)v;

// What endpoint to connect to? this should just be the protocol and host
// part of the URL, e.g. https://test.salesforce.com
-(void)setLoginProtocolAndHost:(NSString *)protocolAndHost;

// set both the endpoint to connect to, and an explicit API version to use.
-(void)setLoginProtocolAndHost:(NSString *)protocolAndHost andVersion:(int)version;

// returns an NSURL of where authentication will currently go.
-(NSURL *)authEndpointUrl;


// thse set of methods pretty much map directly onto their Web Services counterparts.
// These methods will throw a ZKSoapException if there's an error.
//////////////////////////////////////////////////////////////////////////////////////

// Attempt a login request. If a security token is required to be used you need to
// append it to the password parameter.
- (ZKLoginResult *)login:(NSString *)username password:(NSString *)password;

// makes a desribeGlobal call and returns an array of ZKDescribeGlobalSobject instances.
// if describeCaching is enabled, subsequent calls to this will use the locally cached
// copy.
- (NSArray *)describeGlobal;

// makes a describeSObject call and returns a ZKDescribeSObject instance, if describe
// caching is enabled, subsequent requests for the same sobject will return the locally
// cached copy.
- (ZKDescribeSObject *)describeSObject:(NSString *)sobjectName;

// makes a search call with the passed in SOSL expression, returns an array of ZKSObject
// instances.
- (NSArray *)search:(NSString *)sosl;

// makes a query call with the passed in SOQL expression, returns a ZKQueryResult instance.
- (ZKQueryResult *)query:(NSString *)soql;

// makes a queryAll call with the passed in SOQL expression, returns a ZKQueryResult instance.
- (ZKQueryResult *)queryAll:(NSString *)soql;

// makes a queryMore call, pass in the queryLocator from a previous ZKQueryResult instance.
- (ZKQueryResult *)queryMore:(NSString *)queryLocator;

// retreives a set of records, fields is a comma separated list of fields to fetch values for
// ids can be upto 200 record Ids, the returned dictionary is keyed from Id and the dictionary
// values are ZKSObject's.
- (NSDictionary *)retrieve:(NSString *)fields sobject:(NSString *)sobjectType ids:(NSArray *)ids;

// pass an array of ZKSObject's to create in salesforce, returns a matching array of ZKSaveResults
- (NSArray *)create:(NSArray *)objects;

// pass an array of ZKSObject's to update in salesforce, returns a matching array of ZKSaveResults
- (NSArray *)update:(NSArray *)objects;

// pass an array of record Ids to delete from salesforce. returns a matching array of ZKSaveREsults
- (NSArray *)delete:(NSArray *)ids;

// the current server timestamp, as a string (ISO8601 format)
- (NSString *)serverTimestamp;

// makes a setPassword call for the specified userId, with the new password.
- (void)setPassword:(NSString *)newPassword forUserId:(NSString *)userId;


// Information about the current session
//////////////////////////////////////////////////////////////////////////////////////
// returns true if we've performed a login request and it succeeded.
- (BOOL)loggedIn;

// the UserInfo returned by the last call to login.
- (ZKUserInfo *)currentUserInfo;

// the current endpoint URL where requests are being sent.
- (NSString *)serverUrl;

// the short name of the current serverUrl, e.g. na1, eu0, cs5 etc, if the short name ends in -api, the -api part will be removed.
- (NSString *)serverHostAbbriviation;

// the current API session Id being used to make requests.
- (NSString *)sessionId;

// SOAP Headers
//////////////////////////////////////////////////////////////////////////////////////
// Should create/update calls also update the users MRU info? (defaults false)
- (BOOL)updateMru;
- (void)setUpdateMru:(BOOL)aValue;

// If you have a clientIf for a certifed partner application, you can set it here.
- (NSString *)clientId;
- (void)setClientId:(NSString *)aClientId;


// describe caching
//////////////////////////////////////////////////////////////////////////////////////
- (BOOL)cacheDescribes;
- (void)setCacheDescribes:(BOOL)newCacheDescribes;
- (void)flushCachedDescribes;

@end
