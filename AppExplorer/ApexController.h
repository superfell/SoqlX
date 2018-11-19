// Copyright (c) 2010,2018 Simon Fell
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
@class MGSFragariaView;

@interface ApexResult : NSObject {
    NSString                    *debugLog;
    ZKExecuteAnonymousResult    *res;
}
+(ApexResult *)fromResult:(ZKExecuteAnonymousResult *)r andLog:(NSString *)debugLog;

@property (readonly, copy) NSString *debugLog;

@property (readonly) int column;
@property (readonly) int line;
@property (readonly) BOOL compiled;
@property (readonly, copy) NSString *compileProblem;
@property (readonly, copy) NSString *exceptionMessage;
@property (readonly, copy) NSString *exceptionStackTrace;
@property (readonly) BOOL success;

@property (readonly, copy) NSImage *compiledStatusImage;
@property (readonly, copy) NSImage *successImage;

@property (readonly, copy) NSString *resultText;

@end

@interface ApexController : NSObject {
    NSString        *apex;
    ZKApexClient    *apexClient;
    NSMutableArray  *results;

    IBOutlet StandAloneTableHeaderView    *textHeader;
    IBOutlet NSArrayController            *resultsController;
}

-(void)setSforceClient:(ZKSforceClient *)client;

@property (strong) IBOutlet MGSFragariaView *apexTextField;
@property (strong) NSString *apex;

@property (readonly) NSUInteger countOfResults;
-(ApexResult *)objectInResultsAtIndex:(NSUInteger)idx;
-(void)insertObject:(ApexResult *)r inResultsAtIndex:(NSUInteger)idx;
-(void)removeObjectFromResultsAtIndex:(NSUInteger)idx;

-(IBAction)executeApex:(id)sender;

@property (readonly, copy) NSArray *logLevelNames;

@property (strong) NSDictionary *dbLogLevel;
@property (strong) NSDictionary *workflowLogLevel;
@property (strong) NSDictionary *validationLogLevel;
@property (strong) NSDictionary *calloutLogLevel;
@property (strong) NSDictionary *apexCodeLogLevel;
@property (strong) NSDictionary *apexProfilingLogLevel;

@end

