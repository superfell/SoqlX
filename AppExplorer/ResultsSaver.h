// Copyright (c) 2008,2012,2015 Simon Fell
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

@class QueryResultTable;
@class ZKSforceClient;
@class ZKQueryResult;

@interface BufferedWriter : NSObject {
    NSOutputStream    *stream;
    NSMutableData    *buffer;
    NSUInteger        capacity;
}
-(instancetype)initOnStream:(NSOutputStream *)s;

-(void)write:(const uint8_t *)data maxLength:(uint)len;
-(void)flush:(BOOL)ensureFullyFlushed;
-(void)close;

@end

@interface BufferedWriter (StringHelpers) 
-(void)write:(NSString *)s;
-(void)writeQuoted:(NSString *)s;
@end

@interface ResultsSaver : NSObject {
    NSWindow        *progressWindow;
    NSView            *optionsView;
    NSButtonCell    *buttonAll;
    NSButtonCell    *buttonCurrent;
    
    BOOL                saveAll;
    NSOperationQueue    *queryQueue;
    NSOperationQueue    *saveQueue;
    BufferedWriter        *stream;
    ZKSforceClient        *client;
    QueryResultTable    *results;
    NSURL               *filename;
    NSDate                *started;
    
    NSUInteger            rowsWritten;
}

-(instancetype)initWithResults:(QueryResultTable *)res client:(ZKSforceClient *)c NS_DESIGNATED_INITIALIZER;

-(void)save:(NSWindow *)parentWindow;

@property (retain) IBOutlet NSWindow *progressWindow;
@property (retain) IBOutlet NSView *optionsView;
@property (retain) IBOutlet NSButtonCell *buttonAll;
@property (retain) IBOutlet NSButtonCell *buttonCurrent;

@property (assign)   BOOL       saveAll;
@property (assign)   NSUInteger rowsWritten;
@property (readonly) NSUInteger totalRows;
@property (retain)   NSURL      *filename;

@end

