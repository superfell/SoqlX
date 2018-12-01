//
//  SessionIdAuthInfo.m
//  SoqlXplorer
//
//  Created by Simon Fell on 12/1/18.
//

#import "SessionIdAuthInfo.h"

@interface SessionIdAuthInfo ()
@property (copy) NSString *sessionId;
@property (copy) NSURL *instanceUrl;
@end

@implementation SessionIdAuthInfo

@synthesize sessionId, instanceUrl;

-(instancetype)initWithUrl:(NSURL*)url sessionId:(NSString*)sid {
    self = [super init];
    self.instanceUrl = url;
    self.sessionId = sid;
    return self;
}

-(void)refresh {
    // there's no way to refresh a sessionId if it expires.
}

// refresh the sesion if its needed. (this gets called before every soap call)
// returns true if the session was refreshed.
-(BOOL)refreshIfNeeded {
    return NO;
}

@end
