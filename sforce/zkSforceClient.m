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


#import "zkSforceClient.h"
#import "zkPartnerEnvelope.h"
#import "zkQueryResult.h"
#import "zkSaveResult.h"
#import "zkSObject.h"
#import "zkSoapException.h"
#import "zkUserInfo.h"
#import "zkDescribeSObject.h"
#import "zkLoginResult.h"
#import "zkDescribeGlobalSObject.h"
#import "zkParser.h"

static const int MAX_SESSION_AGE = 25 * 60; // 25 minutes
static const int SAVE_BATCH_SIZE = 25;

@interface ZKSforceClient (Private)
- (ZKQueryResult *)queryImpl:(NSString *)value operation:(NSString *)op name:(NSString *)elemName;
- (NSArray *)sobjectsImpl:(NSArray *)objects name:(NSString *)elemName;
- (void)checkSession;
- (ZKLoginResult *)startNewSession;
@end

@implementation ZKSforceClient

- (id)init {
	self = [super init];
	preferedApiVersion = 23;
	[self setLoginProtocolAndHost:@"https://www.salesforce.com"];
	updateMru = NO;
	cacheDescribes = NO;
	return self;
}

- (void)dealloc {
	[authEndpointUrl release];
	[username release];
	[password release];
	[clientId release];
	[sessionId release];
	[sessionExpiresAt release];
	[userInfo release];
	[describes release];
	[super dealloc];
}

- (id)copyWithZone:(NSZone *)zone {
	ZKSforceClient *rhs = [[ZKSforceClient alloc] init];
	[rhs->authEndpointUrl release];
	rhs->authEndpointUrl = [authEndpointUrl copy];
	rhs->endpointUrl = [endpointUrl copy];
	rhs->sessionId = [sessionId copy];
	rhs->username = [username copy];
	rhs->password = [password copy];
	rhs->clientId = [clientId copy];
	rhs->sessionExpiresAt = [sessionExpiresAt copy];
	rhs->userInfo = [userInfo retain];
	rhs->preferedApiVersion = preferedApiVersion;
	[rhs setCacheDescribes:cacheDescribes];
	[rhs setUpdateMru:updateMru];
	return rhs;
}

-(void)setPreferedApiVersion:(int)v {
	preferedApiVersion = v;
}

- (BOOL)updateMru {
	return updateMru;
}

- (void)setUpdateMru:(BOOL)aValue {
	updateMru = aValue;
}

- (BOOL)cacheDescribes {
	return cacheDescribes;
}

- (void)setCacheDescribes:(BOOL)newCacheDescribes {
	if (cacheDescribes == newCacheDescribes) return;
	cacheDescribes = newCacheDescribes;
	[self flushCachedDescribes];
}

- (void)flushCachedDescribes {
	[describes release];
	describes = nil;
	if (cacheDescribes)
		describes = [[NSMutableDictionary alloc] init];
}

- (void)setLoginProtocolAndHost:(NSString *)protocolAndHost {
	[self setLoginProtocolAndHost:protocolAndHost andVersion:preferedApiVersion];
}

- (void)setLoginProtocolAndHost:(NSString *)protocolAndHost andVersion:(int)version {
	[authEndpointUrl release];
	authEndpointUrl = [[NSString stringWithFormat:@"%@/services/Soap/u/%d.0", protocolAndHost, version] retain];
}

- (NSURL *)authEndpointUrl {
	return [NSURL URLWithString:authEndpointUrl];
}

- (ZKLoginResult *)login:(NSString *)un password:(NSString *)pwd {
	[userInfo release];
	userInfo = nil;
	[password release];
	[username release];
	username = [un retain];
	password = [pwd retain];
	return [self startNewSession];
}

- (ZKLoginResult *)startNewSession {
	[sessionExpiresAt release];
	sessionExpiresAt = [[NSDate dateWithTimeIntervalSinceNow:MAX_SESSION_AGE] retain];
	[sessionId release];
	[endpointUrl release];
	endpointUrl = [authEndpointUrl copy];

	ZKEnvelope *env = [[ZKPartnerEnvelope alloc] initWithSessionHeader:nil clientId:clientId];
	[env startElement:@"login"];
	[env addElement:@"username" elemValue:username];
	[env addElement:@"password" elemValue:password];
	[env endElement:@"login"];
	[env endElement:@"s:Body"];
	NSString *xml = [env end];
	
	zkElement *resp = [self sendRequest:xml];	
	zkElement *result = [[resp childElements:@"result"] objectAtIndex:0];
	ZKLoginResult *lr = [[ZKLoginResult alloc] initWithXmlElement:result];
	
	[endpointUrl release];
	endpointUrl = [[lr serverUrl] copy];
	sessionId = [[lr sessionId] copy];

	userInfo = [[lr userInfo] retain];
	[env release];
	return lr;
}

- (BOOL)loggedIn {
	return [sessionId length] > 0;
}

- (void)checkSession {
	if ([sessionExpiresAt timeIntervalSinceNow] < 0)
		[self startNewSession];
}

- (ZKUserInfo *)currentUserInfo {
	return userInfo;
}

- (NSString *)serverUrl {
	return endpointUrl;
}

- (NSString *)sessionId {
	[self checkSession];
	return sessionId;
}


- (NSString *)clientId {
	return clientId;
}

- (void)setClientId:(NSString *)aClientId {
	aClientId = [aClientId copy];
	[clientId release];
	clientId = aClientId;
}

- (void)setPassword:(NSString *)newPassword forUserId:(NSString *)userId {
	if(!sessionId) return;
	[self checkSession];
	
	ZKEnvelope * env = [[[ZKPartnerEnvelope alloc] initWithSessionHeader:sessionId clientId:clientId] autorelease];
	[env startElement:@"setPassword"];
	[env addElement:@"userId" elemValue:userId];
	[env addElement:@"password" elemValue:newPassword];
	[env endElement:@"setPassword"];
	[env endElement:@"s:Body"];
	
	[self sendRequest:[env end]];
}

- (NSArray *)describeGlobal {
	if(!sessionId) return NULL;
	[self checkSession];
	if (cacheDescribes) {
		NSArray *dg = [describes objectForKey:@"describe__global"];	// won't be an sfdc object ever called this.
		if (dg != nil) return dg;
	}
	
	ZKEnvelope * env = [[ZKPartnerEnvelope alloc] initWithSessionHeader:sessionId clientId:clientId];
	[env startElement:@"describeGlobal"];
	[env endElement:@"describeGlobal"];
	[env endElement:@"s:Body"];
	
	zkElement * rr = [self sendRequest:[env end]];
	NSMutableArray *types = [NSMutableArray array]; 
	NSArray *results = [[rr childElement:@"result"] childElements:@"sobjects"];
	NSEnumerator * e = [results objectEnumerator];
	while (rr = [e nextObject]) {
		ZKDescribeGlobalSObject * d = [[ZKDescribeGlobalSObject alloc] initWithXmlElement:rr];
		[types addObject:d];
		[d release];
	}
	[env release];
	if (cacheDescribes)
		[describes setObject:types forKey:@"describe__global"];
	return types;
}

- (ZKDescribeSObject *)describeSObject:(NSString *)sobjectName {
	if (!sessionId) return NULL;
	if (cacheDescribes) {
		ZKDescribeSObject * desc = [describes objectForKey:[sobjectName lowercaseString]];
		if (desc != nil) return desc;
	}
	[self checkSession];
	
	ZKEnvelope * env = [[ZKPartnerEnvelope alloc] initWithSessionHeader:sessionId clientId:clientId];
	[env startElement:@"describeSObject"];
	[env addElement:@"SobjectType" elemValue:sobjectName];
	[env endElement:@"describeSObject"];
	[env endElement:@"s:Body"];
	
	zkElement *dr = [self sendRequest:[env end]];
	zkElement *descResult = [dr childElement:@"result"];
	ZKDescribeSObject *desc = [[[ZKDescribeSObject alloc] initWithXmlElement:descResult] autorelease];
	[env release];
	if (cacheDescribes) 
		[describes setObject:desc forKey:[sobjectName lowercaseString]];
	return desc;
}

- (NSArray *)search:(NSString *)sosl {
	if (!sessionId) return NULL;
	[self checkSession];
	ZKEnvelope *env = [[ZKPartnerEnvelope alloc] initWithSessionHeader:sessionId clientId:clientId];
	[env startElement:@"search"];
	[env addElement:@"searchString" elemValue:sosl];
	[env endElement:@"search"];
	[env endElement:@"s:Body"];
	
	zkElement *sr = [self sendRequest:[env end]];
	zkElement *searchResult = [sr childElement:@"result"];
	NSArray *records = [[searchResult childElement:@"searchRecords"] childElements:@"record"];
	NSMutableArray *sobjects = [NSMutableArray array];
	for (zkElement *soNode in records)
		[sobjects addObject:[ZKSObject fromXmlNode:soNode]];
	[env release];
	return sobjects;	
}

- (NSString *)serverTimestamp {
	if (!sessionId) return NULL;
	[self checkSession];
	ZKEnvelope *env = [[ZKPartnerEnvelope alloc] initWithSessionHeader:sessionId clientId:clientId];
	[env startElement:@"getServerTimestamp"];
	[env endElement:@"getServerTimestamp"];
	[env endElement:@"s:Body"];
	
	zkElement *res = [self sendRequest:[env end]];
	zkElement *timestamp = [res childElement:@"result"];
	[env release];
	return [timestamp stringValue];
}

- (ZKQueryResult *)query:(NSString *) soql {
	return [self queryImpl:soql operation:@"query" name:@"queryString"];
}

- (ZKQueryResult *)queryAll:(NSString *) soql {
	return [self queryImpl:soql operation:@"queryAll" name:@"queryString"];
}

- (ZKQueryResult *)queryMore:(NSString *)queryLocator {
	return [self queryImpl:queryLocator operation:@"queryMore" name:@"queryLocator"];
}

- (NSArray *)create:(NSArray *)objects {
	return [self sobjectsImpl:objects name:@"create"];
}

- (NSArray *)update:(NSArray *)objects {
	return [self sobjectsImpl:objects name:@"update"];
}

- (NSArray *)sobjectsImpl:(NSArray *)objects name:(NSString *)elemName {
	if(!sessionId) return NULL;
	[self checkSession];
	
	// if more than we can do in one go, break it up.
	if ([objects count] > SAVE_BATCH_SIZE) {
		NSMutableArray *allResults = [NSMutableArray arrayWithCapacity:[objects count]];
		NSRange rng = {0, MIN(SAVE_BATCH_SIZE, [objects count])};
		while (rng.location < [objects count]) {
			[allResults addObjectsFromArray:[self sobjectsImpl:[objects subarrayWithRange:rng] name:elemName]];
			rng.location += rng.length;
			rng.length = MIN(SAVE_BATCH_SIZE, [objects count] - rng.location);
		}
		return allResults;
	}
	ZKEnvelope *env = [[ZKPartnerEnvelope alloc] initWithSessionAndMruHeaders:sessionId mru:updateMru clientId:clientId];
	[env startElement:elemName];
	NSEnumerator *e = [objects objectEnumerator];
	ZKSObject *o;
	while (o = [e nextObject])
		[env addElement:@"sobject" elemValue:o];
	[env endElement:elemName];
	[env endElement:@"s:Body"];

	zkElement *cr = [self sendRequest:[env end]];
	NSArray *resultsArr = [cr childElements:@"result"];
	NSMutableArray *results = [NSMutableArray arrayWithCapacity:[resultsArr count]];
	for (zkElement *cr in resultsArr) {
		ZKSaveResult * sr = [[ZKSaveResult alloc] initWithXmlElement:cr];
		[results addObject:sr];
		[sr release];
	}
	[env release];
	return results;
}

- (NSDictionary *)retrieve:(NSString *)fields sobject:(NSString *)sobjectType ids:(NSArray *)ids {
	if(!sessionId) return NULL;
	[self checkSession];
	
	ZKEnvelope * env = [[ZKPartnerEnvelope alloc] initWithSessionHeader:sessionId clientId:clientId];
	[env startElement:@"retrieve"];
	[env addElement:@"fieldList" elemValue:fields];
	[env addElement:@"sObjectType" elemValue:sobjectType];
	[env addElementArray:@"ids" elemValue:ids];
	[env endElement:@"retrieve"];
	[env endElement:@"s:Body"];
	
	zkElement *rr = [self sendRequest:[env end]];
	NSMutableDictionary *sobjects = [NSMutableDictionary dictionary]; 
	NSArray *results = [rr childElements:@"result"];
	for (zkElement *res in results) {
		ZKSObject *o = [[ZKSObject alloc] initFromXmlNode:res];
		[sobjects setObject:o forKey:[o id]];
		[o release];
	}
	[env release];
	return sobjects;
}

- (NSArray *)delete:(NSArray *)ids {
	if(!sessionId) return NULL;
	[self checkSession];

	ZKEnvelope *env = [[ZKPartnerEnvelope alloc] initWithSessionAndMruHeaders:sessionId mru:updateMru clientId:clientId];
	[env startElement:@"delete"];
	[env addElement:@"ids" elemValue:ids];
	[env endElement:@"delete"];
	[env endElement:@"s:Body"];
	
	zkElement *cr = [self sendRequest:[env end]];
	NSArray *resArr = [cr childElements:@"result"];
	NSMutableArray *results = [NSMutableArray arrayWithCapacity:[resArr count]];
	for (zkElement *cr in resArr) {
		ZKSaveResult *sr = [[ZKSaveResult alloc] initWithXmlElement:cr];
		[results addObject:sr];
		[sr release];
	}
	[env release];
	return results;
}

- (ZKQueryResult *)queryImpl:(NSString *)value operation:(NSString *)operation name:(NSString *)elemName {
	if(!sessionId) return NULL;
	[self checkSession];

	ZKEnvelope *env = [[ZKPartnerEnvelope alloc] initWithSessionHeader:sessionId clientId:clientId];
	[env startElement:operation];
	[env addElement:elemName elemValue:value];
	[env endElement:operation];
	[env endElement:@"s:Body"];
	
	zkElement *qr = [self sendRequest:[env end]];
	ZKQueryResult *result = [[ZKQueryResult alloc] initFromXmlNode:[[qr childElements] objectAtIndex:0]];
	[env release];
	return [result autorelease];
}

@end
