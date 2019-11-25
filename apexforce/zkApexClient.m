// Copyright (c) 2007,2013 Simon Fell
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

#import "zkApexClient.h"
#import <ZKSforce/ZKEnvelope.h>
#import "ZKCompileResult.h"
#import "zkExecuteAnonResult.h"
#import "zkRunTestResult.h"
#import <ZKSforce/ZKParser.h>

@interface ZKApexClient ()
@property (readwrite, atomic) NSString *lastDebugLog;
@end

@implementation ZKApexClient

#define APEX_WS_NS   @"http://soap.sforce.com/2006/08/apex"
#define SOAP_ENV_NS  @"http://schemas.xmlsoap.org/soap/envelope/"

@synthesize debugLog, lastDebugLog;

static NSArray *logLevelNames;

-(NSString *)stringOfLogCategory:(ZKLogCategory)c {
    switch (c) {
    case Category_Db: return @"Db";
    case Category_Workflow: return @"Workflow";
    case Category_Validation: return @"Validation";
    case Category_Callout: return @"Callout";
    case Category_Apex_code: return @"Apex_code";
    case Category_Apex_profiling: return @"Apex_profiling";
    case Category_All: return @"All";
    }
    @throw [NSException exceptionWithName:@"Unexpected log category" reason:[NSString stringWithFormat:@"LogCategory of %d is not valid", c] userInfo:nil];
}

+(NSString *)stringOfLogLevel:(ZKLogCategoryLevel)l {
    switch (l) {
    case Level_Internal: return @"Internal";
    case Level_Finest: return @"Finest";
    case Level_Finer: return @"Finer";
    case Level_Fine: return @"Fine";
    case Level_Debug: return @"Debug";
    case Level_Info: return @"Info";
    case Level_Warn: return @"Warn";
    case Level_Error: return @"Error";
    case Level_None: return @"None";
    }
    @throw [NSException exceptionWithName:@"Unexpected log level" reason:[NSString stringWithFormat:@"LogLevel of %d is not valid", l] userInfo:nil];
}

+(void)initialize {
    NSMutableArray *a = [NSMutableArray array];
    for (int i =0; i < 9; i++) {
        NSDictionary *d = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:i], @"Level", [ZKApexClient stringOfLogLevel:i], @"Name", nil];
        [a addObject:d];
    }
    logLevelNames = a;
}

+ (id) fromClient:(ZKSforceClient *)sf {
    return [[ZKApexClient alloc] initFromClient:sf];
}

- (id) initFromClient:(ZKSforceClient *)sf {
    self = [super init];
    sforce = sf;
    debugLog = NO;
    for (int i = 0; i < ZKLogCategory_Count; i++)
        loggingLevels[i] = Level_None;
    return self;
}

-(ZKLogCategoryLevel)debugLevelForCategory:(ZKLogCategory)c {
    return loggingLevels[c];
}

-(void)setDebugLevel:(ZKLogCategoryLevel)lvl forCategory:(ZKLogCategory)c {
    loggingLevels[c] = lvl;
}

+(NSArray *)logLevelNames {
    return logLevelNames;
}

- (void)setEndpointUrl {
    NSString *sUrl = [[sforce serverUrl] absoluteString];
    sUrl = [sUrl stringByReplacingOccurrencesOfString:@"/services/Soap/u/" withString:@"/services/Soap/s/"];
    self.endpointUrl = [NSURL URLWithString:sUrl];
}

- (ZKEnvelope *)startEnvelope {
    ZKEnvelope *e = [[ZKEnvelope alloc] init];
    [e start:APEX_WS_NS];
    [e writeSessionHeader:[sforce sessionId]];
    [e writeCallOptionsHeader:[sforce clientId]];
    if ([self debugLog]) {
        [e startElement:@"DebuggingHeader"];
        for (int i =0; i < ZKLogCategory_Count; i++) {
            if (loggingLevels[i] != Level_None) {
                [e startElement:@"categories"];
                [e addElementString:@"category" elemValue:[self stringOfLogCategory:i]];
                [e addElementString:@"level" elemValue:[ZKApexClient stringOfLogLevel:loggingLevels[i]]];
                [e endElement:@"categories"];
            }
        }
        [e endElement:@"DebuggingHeader"];
    }
    [e moveToBody];
    [self setEndpointUrl];
    return e;
}

-(NSString *)getResponseDebugLog:(ZKElement *)soapRoot {
    ZKElement *headers = [soapRoot childElement:@"Header" ns:SOAP_ENV_NS];
    ZKElement *debugInfo = [headers childElement:@"DebuggingInfo" ns:APEX_WS_NS];
    ZKElement *debugLogE = [debugInfo childElement:@"debugLog" ns:APEX_WS_NS];
    return [debugLogE stringValue];
}

- (void)sendAndParseResults:(ZKEnvelope *)requestEnv name:(NSString *)callName resultType:(Class)resultClass
                  failBlock:(ZKFailWithErrorBlock)failBlock
              completeBlock:(ZKCompleteArrayBlock)completeBlock {
    
    NSString *soapRequest = [requestEnv end];
    [self startRequest:soapRequest name:callName handler:^void(ZKElement *root, NSError *err) {
        if (err != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                failBlock(err);
            });
            return;
        }
        NSString *debugLogStr = [self getResponseDebugLog:root];
        [self setLastDebugLog:debugLogStr];
        
        ZKElement *body = [root childElement:@"Body" ns:SOAP_ENV_NS];
        ZKElement *resRoot = [[body childElements] objectAtIndex:0];
        
        NSArray * results = [resRoot childElements:@"result"];
        NSMutableArray *resArr = [NSMutableArray arrayWithCapacity:[results count]];
        for (ZKElement *child in results) {
            NSObject *o = [[resultClass alloc] initWithXmlElement:child];
            [resArr addObject:o];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            completeBlock(resArr);
        });
    }];
}

- (void)compile:(NSString *)elemName src:(NSArray *)src withFailBlock:(ZKFailWithErrorBlock)failBlock completeBlock:(ZKCompleteArrayBlock)completeBlock {
    ZKEnvelope * env = [self startEnvelope];
    [env startElement:elemName];
    [env addElementArray:@"scripts" elemValue:src];
    [env endElement:elemName];
    return [self sendAndParseResults:env name:[NSString stringWithFormat:@"%@:", elemName] resultType:[ZKCompileResult class]
                           failBlock:failBlock completeBlock:completeBlock];
}

-(void)compilePackages:(NSArray *)src withFailBlock:(ZKFailWithErrorBlock)failBlock completeBlock:(ZKCompleteArrayBlock)completeBlock {
    [self compile:@"compilePackages" src:src withFailBlock:failBlock completeBlock:completeBlock];
}

-(void)compileTriggers:(NSArray *)src withFailBlock:(ZKFailWithErrorBlock)failBlock completeBlock:(ZKCompleteArrayBlock)completeBlock {
    [self compile:@"compileTriggers" src:src withFailBlock:failBlock completeBlock:completeBlock];
}

-(void)executeAnonymous:(NSString *)src withFailBlock:(ZKFailWithErrorBlock)failBlock
                                        completeBlock:(void(^)(ZKExecuteAnonymousResult *r))completeBlock {

    ZKEnvelope * env = [self startEnvelope];
    [env startElement:@"executeAnonymous"];
    [env addElement:@"String" elemValue:src];
    [env endElement:@"executeAnonymous"];
    [self sendAndParseResults:env name:NSStringFromSelector(_cmd) resultType:[ZKExecuteAnonymousResult class]
                    failBlock:failBlock
                completeBlock:^(NSArray *result) {
        completeBlock(result[0]);
    }];
}

-(void)runTests:(BOOL)allTests namespace:(NSString *)ns packages:(NSArray *)pkgs
                           withFailBlock:(ZKFailWithErrorBlock)failBlock
                           completeBlock:(void(^)(ZKRunTestResult *r))completeBlock {

    ZKEnvelope *env = [self startEnvelope];
    [env startElement:@"runTests"];
    [env startElement:@"RunTestsRequest"];
    [env addElement:@"allTests" elemValue:allTests ? @"true" : @"false"];
    [env addElement:@"namespace" elemValue:ns];
    [env addElement:@"packages" elemValue:pkgs];
    [env endElement:@"RunTestsRequest"];
    [env endElement:@"runTests"];
    [self sendAndParseResults:env name:NSStringFromSelector(_cmd) resultType:[ZKRunTestResult class] failBlock:failBlock completeBlock:^(NSArray *result) {
        completeBlock(result[0]);
    }];
}

@end
