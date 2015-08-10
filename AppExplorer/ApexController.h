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

@property (retain) IBOutlet NSTextView *apexTextField;
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

