// Copyright (c) 2010 Simon Fell
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

#import "ApexController.h"
#import "zkSforceClient.h"
#import "zkApexClient.h"
#import "zkExecuteAnonResult.h"
#import "StandAloneTableHeaderView.h"

@implementation ApexResult

-(id)initWithResult:(ZKExecuteAnonymousResult *)r andLog:(NSString *)log {
	self = [super init];
	debugLog = [log retain];
	res = [r retain];
	return self;
}
	
+(ApexResult *)fromResult:(ZKExecuteAnonymousResult *)r andLog:(NSString *)debugLog {
	return [[[ApexResult alloc] initWithResult:r andLog:debugLog] autorelease];
}

// NSImageNameStatusAvailable NSImageNameStatusUnavailable

-(NSImage *)compiledStatusImage {
	return [NSImage imageNamed:[self compiled] ? @"greenLight" : @"redLight"];
}

-(NSImage *)successImage {
	return [NSImage imageNamed:[self success] ? @"greenLight" : @"redLight"];
}

-(NSString *)debugLog {
	return debugLog;
}

- (int)column {
	return [res column];
}

- (int)line {
	return [res line];
}

- (BOOL)compiled {
	return [res compiled];
}

- (NSString *)compileProblem {
	return [res compileProblem];
}

- (NSString *)exceptionMessage {
	return [res exceptionMessage];
}

- (NSString *)exceptionStackTrace {
	return [res exceptionStackTrace];
}

- (BOOL)success {
	return [res success];
}

-(NSString *)resultText {
	return [self success] ? @"Success" : [self compiled] ? [self exceptionMessage] : [self compileProblem];
}

@end

@implementation ApexController

@synthesize apex;

-(void)awakeFromNib {
	[textHeader setHeaderText:@"Anonymous Apex"];
	results = [[NSMutableArray arrayWithCapacity:20] retain];
	[self setApex:[[NSUserDefaults standardUserDefaults] objectForKey:@"LastApexExec"]];
    [self.apexTextField setEnabledTextCheckingTypes:0];
    [self.apexTextField setSmartInsertDeleteEnabled:NO];
}

-(void)dealloc {
	[apex release];
	[results release];
	[apexClient release];
    self.apexTextField = nil;
	[super dealloc];
}

-(void)setDebugSettingsFromDefaults {
	NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
	NSArray *props = [NSArray arrayWithObjects:@"dbLogLevel", @"workflowLogLevel", @"validationLogLevel", @"calloutLogLevel", @"apexCodeLogLevel", @"apexProfilingLogLevel", nil];
	for (NSString *p in props) 
		[self willChangeValueForKey:p];

	for (int c = 0; c < 6; c++) {
		int lvl = [ud integerForKey:[NSString stringWithFormat:@"apexDebugLevel_%d", c]];
		[apexClient setDebugLevel:lvl forCategory:c];
	}

	for (NSString *p in props) 
		[self didChangeValueForKey:p];
}

-(void)setSforceClient:(ZKSforceClient *)client {
	[apexClient autorelease];
	apexClient = [[ZKApexClient fromClient:client] retain];
	[apexClient setDebugLog:YES];
	[self setDebugSettingsFromDefaults];
}

-(IBAction)executeApex:(id)sender {
	ZKExecuteAnonymousResult *r = [apexClient executeAnonymous:[self apex]];
	NSString *deb = [apexClient lastDebugLog];
	ApexResult *ar = [ApexResult fromResult:r andLog:deb];
	NSLog(@"res %@", [ar resultText]);
	[self insertObject:ar inResultsAtIndex:0];
	[[NSUserDefaults standardUserDefaults] setObject:[self apex] forKey:@"LastApexExec"];
	[resultsController setSelectionIndex:0];
//	[self setSelectedResult:[NSIndexSet indexSetWithIndex:0]];
}

-(NSUInteger)countOfResults {
	return [results count];
}

-(ApexResult *)objectInResultsAtIndex:(NSUInteger)idx {
	return [results objectAtIndex:idx];
}

-(void)insertObject:(ApexResult *)r inResultsAtIndex:(NSUInteger)idx {
	[results insertObject:r atIndex:idx];
}

-(void)removeObjectFromResultsAtIndex:(NSUInteger)idx {
	[results removeObjectAtIndex:idx];
}

-(NSArray *)logLevelNames {
	return [ZKApexClient logLevelNames];
}

-(NSDictionary *)logLevelForCategory:(ZKLogCategory) c {
	ZKLogCategoryLevel l = [apexClient debugLevelForCategory:c];
	for (NSDictionary *d in [ZKApexClient logLevelNames])
		if (l == [[d objectForKey:@"Level"] intValue])
			return d;
	return nil;		
}

-(void)setLogLevel:(NSDictionary *)d forCategory:(ZKLogCategory)c {
	[apexClient setDebugLevel:[[d objectForKey:@"Level"] intValue] forCategory:c];
	[[NSUserDefaults standardUserDefaults] setInteger:[[d objectForKey:@"Level"] intValue] forKey:[NSString stringWithFormat:@"apexDebugLevel_%d", c]];
}

-(NSDictionary *)dbLogLevel {
	return [self logLevelForCategory:Category_Db];
}

-(NSDictionary *)workflowLogLevel {
	return [self logLevelForCategory:Category_Workflow];
}

-(NSDictionary *)validationLogLevel {
	return [self logLevelForCategory:Category_Validation];
}

-(NSDictionary *)calloutLogLevel {
	return [self logLevelForCategory:Category_Callout];
}

-(NSDictionary *)apexCodeLogLevel {
	return [self logLevelForCategory:Category_Apex_code];
}

-(NSDictionary *)apexProfilingLogLevel {
	return [self logLevelForCategory:Category_Apex_profiling];
}

-(void)setDbLogLevel:(NSDictionary *)d {
	[self setLogLevel:d forCategory:Category_Db];
}

-(void)setWorkflowLogLevel:(NSDictionary *)d {
	[self setLogLevel:d forCategory:Category_Workflow];
}

-(void)setValidationLogLevel:(NSDictionary *)d {
	[self setLogLevel:d forCategory:Category_Validation];
}

-(void)setCalloutLogLevel:(NSDictionary *)d {
	[self setLogLevel:d forCategory:Category_Callout];
}

-(void)setApexCodeLogLevel:(NSDictionary *)d {
	[self setLogLevel:d forCategory:Category_Apex_code];
}

-(void)setApexProfilingLogLevel:(NSDictionary *)d {
	[self setLogLevel:d forCategory:Category_Apex_profiling];
}

@end
