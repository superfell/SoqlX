//
//  ApexController.h
//  AppExplorer
//
//  Created by Simon Fell on 10/14/10.
//  Copyright 2010 Simon Fell. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class ZKApexClient;
@class ZKSforceClient;
@class StandAloneTableHeaderView;
@class ZKExecuteAnonymousResult;

@interface ApexResult : NSObject {
	NSString					*debugLog;
	ZKExecuteAnonymousResult	*res;
}
+(ApexResult *)fromResult:(ZKExecuteAnonymousResult *)r andLog:(NSString *)debugLog;

-(NSString *)debugLog;

- (int)column;
- (int)line;
- (BOOL)compiled;
- (NSString *)compileProblem;
- (NSString *)exceptionMessage;
- (NSString *)exceptionStackTrace;
- (BOOL)success;

-(NSImage *)compiledStatusImage;
-(NSImage *)successImage;

-(NSString *)resultText;

@end

@interface ApexController : NSObject {
	NSString		*apex;
	ZKApexClient	*apexClient;
	NSMutableArray	*results;

	IBOutlet StandAloneTableHeaderView	*textHeader;
	IBOutlet NSArrayController			*resultsController;
}

-(void)setSforceClient:(ZKSforceClient *)client;

@property (retain) NSString *apex;

-(NSUInteger)countOfResults;
-(ApexResult *)objectInResultsAtIndex:(NSUInteger)idx;
-(void)insertObject:(ApexResult *)r inResultsAtIndex:(NSUInteger)idx;
-(void)removeObjectFromResultsAtIndex:(NSUInteger)idx;

-(IBAction)executeApex:(id)sender;

-(NSArray *)logLevelNames;

@property (retain) NSDictionary *dbLogLevel;
@property (retain) NSDictionary *workflowLogLevel;
@property (retain) NSDictionary *validationLogLevel;
@property (retain) NSDictionary *calloutLogLevel;
@property (retain) NSDictionary *apexCodeLogLevel;
@property (retain) NSDictionary *apexProfilingLogLevel;

@end

