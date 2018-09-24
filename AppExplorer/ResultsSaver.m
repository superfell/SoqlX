// Copyright (c) 2008,2015,2018 Simon Fell
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

#import "ResultsSaver.h"
#import "QueryResultTable.h"
#import "zkSforce.h"
#import "zkQueryResult+NSTableView.h"
#import "EditableQueryResultWrapper.h"

@implementation ResultsSaver

@synthesize progressWindow, optionsView, buttonAll, buttonCurrent;
@synthesize saveAll, rowsWritten, filename;

-(instancetype)initWithResults:(QueryResultTable *)r client:(ZKSforceClient *)c {
    self = [super init];
    results = r;
    if ([results.queryResult queryLocator] != nil) {
        [[NSBundle mainBundle] loadNibNamed:@"querySavePanel" owner:self topLevelObjects:nil];
        buttonAll.title = [NSString stringWithFormat:buttonAll.title, [results.queryResult size]];
        buttonCurrent.title = [NSString stringWithFormat:buttonCurrent.title, [results.queryResult records].count];
    }
    client = c;
    queryQueue = [[NSOperationQueue alloc] init];
    queryQueue.maxConcurrentOperationCount = 1;
    saveQueue = [[NSOperationQueue alloc] init];
    saveQueue.maxConcurrentOperationCount = 1;
    return self;
}

- (void)save:(NSWindow *)parentWindow {
    NSSavePanel *sp = [NSSavePanel savePanel];
    sp.allowedFileTypes = @[@"csv"];
    [sp setAllowsOtherFileTypes:YES];
    [sp setCanSelectHiddenExtension:YES];
    sp.accessoryView = optionsView;
    [sp beginSheetModalForWindow:parentWindow completionHandler:^(NSInteger result) {
        if (result == NSModalResponseCancel) {
            // TODO [self autorelease];
            return;
        }
        self.filename = sp.URL;
        dispatch_async(dispatch_get_main_queue(), ^() {
            [self startWrite:parentWindow];
        });
//        [self performSelectorOnMainThread:@selector(startWrite:) withObject:(__bridge id _Nullable)(contextInfo) waitUntilDone:NO];
//        [self savePanelDidEnd:sp returnCode:result contextInfo:(__bridge void *)(parentWindow)];
    }];
}

-(NSUInteger)totalRows {
    return results.queryResult.size;
}

-(NSArray *)columns {
    return results.table.tableColumns;
}

-(void)startWrite:(NSWindow*)parentWindow {
    self.rowsWritten = 0;
    if (saveAll)
        [NSApp beginSheet:progressWindow modalForWindow:parentWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
    
    started = [NSDate date];
    NSOutputStream *s = [NSOutputStream outputStreamWithURL:filename append:NO];
    [s open];
    stream = [[BufferedWriter alloc] initOnStream:s];
    
    ZKQueryResult *qr = results.queryResult;
    BOOL first = YES;
    for (NSTableColumn *c in [self columns]) {
        if ([[results.wrapper allSystemColumnIdentifiers] containsObject:c.identifier])
            continue;
        if (!first)
            [stream write:@","];
        first = NO;
        [stream writeQuoted:c.headerCell.stringValue];
    }
    [stream write:@"\n"];

    client = [client copyWithZone:nil];

    NSInvocationOperation *sop = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(writeResults:) object:qr];
    [saveQueue addOperation:sop];
}

-(void)endWrite {
    NSTimeInterval ttaken = [[NSDate date] timeIntervalSinceDate:started];
    NSLog(@"query result saving complete, %lu rows in %f seconds (%d rows per hour)", (unsigned long)rowsWritten, ttaken, (int)(rowsWritten * 3600 / ttaken) );
    [stream close];
    if (saveAll) {
        [NSApp endSheet:progressWindow];
        [progressWindow orderOut:self];
        progressWindow = nil;
    }
}

-(void)queryMore:(id)locator {
    ZKQueryResult *qr = [client queryMore:locator];
    NSInvocationOperation *sop = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(writeResults:) object:qr];
    [saveQueue addOperation:sop];
}

-(void)queueQueryMore:(NSString *)ql {
    if (ql.length == 0 || !saveAll) return;
    NSInvocationOperation *q = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(queryMore:) object:ql];
    [queryQueue addOperation:q];
}

-(void)incrementRowCount:(NSNumber *)n {
    NSUInteger tr = rowsWritten + n.integerValue;
    self.rowsWritten = tr;
}

-(void)updateRowCount:(NSInteger)rows {
    [self performSelectorOnMainThread:@selector(incrementRowCount:) withObject:@(rows) waitUntilDone:NO];
}

-(void)writeResults:(id)data {
    ZKQueryResult *qr = (ZKQueryResult *)data;
    [self queueQueryMore:[qr queryLocator]];
    NSInteger rows = [qr numberOfRowsInTableView:nil];
    for (NSInteger i = 0; i < rows; i++) {
        BOOL first = YES;
        for (NSTableColumn *c in [self columns]) {
            if ([[results.wrapper allSystemColumnIdentifiers] containsObject:c.identifier])
                continue;
            if (first) {
                first = NO;
            } else {
                [stream write:@","];
            }
            NSObject *v = [qr tableView:nil objectValueForTableColumn:c row:i];
            NSString *s = nil;
            if ([v isKindOfClass:[NSString class]]) {
                s = (NSString *)v;
            } else if ([v isKindOfClass:[NSNumber class]]) {
                s = ((NSNumber *)v).stringValue;
            } else if ([v isKindOfClass:[ZKQueryResult class]]) {
                ZKQueryResult *child = (ZKQueryResult *)v;
                s = [NSString stringWithFormat:@"[%ld child rows]", (long)child.size];
            } else if (v != nil && ![v isKindOfClass:[NSString class]]) {
                NSLog(@"expected NSString, but got %@ for column %@, row %ld", [v class], c.identifier, (long)i);
                s = v.description;
            }
            [stream writeQuoted:s];
        }
        [stream write:@"\n"];
    }
    [self updateRowCount:rows];
    if ([qr done] || !saveAll) {
        [self performSelectorOnMainThread:@selector(endWrite) withObject:nil waitUntilDone:NO];
    }
}

@end

@implementation BufferedWriter 

-(instancetype)initOnStream:(NSOutputStream *)s capacity:(NSUInteger)cap {
    self = [super init];
    stream = s;
    buffer = [[NSMutableData alloc] initWithCapacity:cap];
    capacity = cap;
    return self;
}

-(instancetype)initOnStream:(NSOutputStream *)s {
    return [self initOnStream:s capacity:64*1024];
}


-(void)write:(const uint8_t *)data maxLength:(NSUInteger)len {
    if (len < (capacity - buffer.length)) {
        [buffer appendBytes:data length:len];
    } else if (len < capacity) {
        [self flush:FALSE];
        [buffer appendBytes:data length:len];
    } else {
        [self flush:TRUE];
        [stream write:data maxLength:len];
    }
}

-(void)flush:(BOOL)ensureFullyFlushed {
    while (buffer.length > 0) {
        NSInteger written = [stream write:buffer.mutableBytes maxLength:buffer.length];
        if (written == buffer.length) {
            buffer.length = 0;
            return;
        } else {
            NSLog(@"stream:write returned less than supplied written=%ld, maxLength=%ld", written, buffer.length);
            memmove([buffer mutableBytes], [buffer mutableBytes] + written, [buffer length] - written);
            buffer.length = buffer.length - written;
        }
        if (ensureFullyFlushed) {
            [NSThread sleepForTimeInterval:0.001];
        } else {
            return;
        }
    }
}

-(void)close {
    [self flush:TRUE];
    [stream close];
}

// String helpers
-(void)write:(NSString *)s {
    if (s == nil || s.length == 0) return;
    [self write:(const uint8_t *)s.UTF8String maxLength:[s lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];
}

-(void)writeQuoted:(NSString *)s {
    [self write:(const uint8_t *)"\"" maxLength:1];
    [self write:[s stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""]];
    [self write:(const uint8_t *)"\"" maxLength:1];
}

@end
