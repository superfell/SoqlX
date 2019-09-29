// Copyright (c) 2009,2018 Simon Fell
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

#import "BulkDelete.h"
#import "ProgressController.h"
#import "EditableQueryResultWrapper.h"
#import "zkSforce.h"
#import "QueryResultTable.h"

@interface BulkDelete ()
-(void)doDeleteFrom:(NSInteger)start length:(NSInteger)length;

@property (strong) QueryResultTable *table;
@end

@implementation BulkDelete

@synthesize table;

-(instancetype)initWithClient:(ZKSforceClient *)c {
    self = [super init];
    progress = [[ProgressController alloc] init];
    queue = [[NSOperationQueue alloc] init];
    queue.maxConcurrentOperationCount = 1;
    client = c;
    return self;
}

-(void)extractRows:(EditableQueryResultWrapper *)dataSource {
    NSSet *idxSet = [dataSource indexesOfCheckedRows];
    ZKQueryResult *data = [dataSource queryResult];
    NSMutableArray *ia  = [NSMutableArray arrayWithCapacity:idxSet.count];
    NSMutableArray *ids = [NSMutableArray arrayWithCapacity:idxSet.count];
    for (NSNumber *idx in idxSet) {
        [ia addObject:idx];
        ZKSObject *row = [data records][idx.integerValue];
        [ids addObject:[row id]];
    }
    indexes = ia;
    sfdcIds = ids;
    results = [NSMutableArray arrayWithCapacity:idxSet.count];
}

-(void)performBulkDelete:(QueryResultTable *)queryResultTable window:(NSWindow *)modalWindow {
    self.table = queryResultTable;
    EditableQueryResultWrapper *dataSource = queryResultTable.wrapper;
    progress.progressLabel = [NSString stringWithFormat:@"Deleting %lu rows", (unsigned long)[dataSource numCheckedRows]];
    progress.progressValue = 1.0;
    [modalWindow beginSheet:progress.progressWindow completionHandler:nil];
    [self extractRows:dataSource];

    // enqueue delete operations
    NSInteger start = 0;
    NSInteger chunk = 50;
    do {
        NSInteger len = indexes.count - start;
        if (len > chunk) len = chunk;
        NSBlockOperation *op = [NSBlockOperation blockOperationWithBlock:^{
            [self doDeleteFrom:start length:len];
        }];
        [queue addOperation:op];
        start += len;
    } while (start < indexes.count);
}

-(void)deletesFinished {
    int cnt = 0;
    // save errors to table
    [table.wrapper clearErrors];
    NSMutableArray *deleted = [NSMutableArray array];
    for (ZKSaveResult *r in results) {
        NSNumber *idx = indexes[cnt];
        if (r.success) {
            [deleted addObject:idx];
            [table.wrapper setChecked:NO onRowWithIndex:idx];
        } else {
            [table.wrapper addError:r.description forRowIndex:idx];
        }
        ++cnt;
    }
    [table showHideErrorColumn];
    // remove the successfully deleted rows from the queryResults.
    NSArray *sorted = [deleted sortedArrayUsingSelector:@selector(compare:)];
    id ctx = [table.wrapper createMutatingRowsContext];
    NSNumber *idx;
    NSEnumerator *e = [sorted reverseObjectEnumerator];
    while (idx = [e nextObject])
        [table.wrapper remmoveRowAtIndex:idx.integerValue context:ctx];
    [table.wrapper updateRowsFromContext:ctx];
    [table replaceQueryResult:[table.wrapper queryResult]];
    
    // remove the progress sheet, and tidy up
    [NSApp endSheet:progress.progressWindow];
    [progress.progressWindow orderOut:self];
     // we're outa here
}

-(void)aboutToDeleteFromIndex:(NSNumber *)idx {
    NSString *l = [NSString stringWithFormat:@"Deleting %d of %ld rows", idx.intValue, (unsigned long)indexes.count];
    progress.progressLabel = l;
}

-(void)doDeleteFrom:(NSInteger)start length:(NSInteger)length {
    [self performSelectorOnMainThread:@selector(aboutToDeleteFromIndex:) withObject:@(start+length) waitUntilDone:NO];
    NSArray *ids = [sfdcIds subarrayWithRange:NSMakeRange(start, length)];
    [client delete:ids failBlock:^(NSError *result) {
        [[NSAlert alertWithError:result] runModal];
    } completeBlock:^(NSArray *res) {
        [self->results addObjectsFromArray:res];
        if (self->results.count == self->sfdcIds.count) {
            // all done, lets wrap up
            [self performSelectorOnMainThread:@selector(deletesFinished) withObject:nil waitUntilDone:NO];
        }
    }];
}

@end
