// Copyright (c) 2009,2018,2020 Simon Fell
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
#import <ZKSforce/ZKSforce.h>
#import "ProgressController.h"
#import "EditableQueryResultWrapper.h"
#import "QueryResultTable.h"

@interface BulkDelete ()
-(NSArray<ZKSObject*>*)extractRows:(EditableQueryResultWrapper *)dataSource;
-(void)deleteInChunks:(NSArray<ZKSObject*>*)rows start:(NSUInteger)start chunk:(NSUInteger)chunkSize;
-(void)deletesFinished:(NSArray<ZKSObject*>*)rows withError:(NSError*)err;

@property ProgressController  *progress;
@property ZKSforceClient      *client;

@property NSMutableArray      *results;
@property QueryResultTable    *table;

@end

@implementation BulkDelete

-(instancetype)initWithClient:(ZKSforceClient *)c {
    self = [super init];
    self.progress = [[ProgressController alloc] init];
    self.client = c;
    return self;
}

-(void)performBulkDelete:(QueryResultTable *)queryResultTable window:(NSWindow *)modalWindow {
    NSArray<ZKSObject*> *toDelete = [self extractRows:queryResultTable.wrapper];
    self.table = queryResultTable;
    self.progress.progressLabel = [NSString stringWithFormat:@"Deleting %lu rows", (unsigned long)toDelete.count];
    self.progress.progressValue = 1.0;
    [modalWindow beginSheet:self.progress.progressWindow completionHandler:nil];

    // chunk up delete requests.
    self.results = [NSMutableArray arrayWithCapacity:toDelete.count];
    [self deleteInChunks:toDelete start:0 chunk:50];
}

-(NSArray<ZKSObject*>*)extractRows:(EditableQueryResultWrapper *)dataSource {
    NSMutableArray<ZKSObject*> *checked = [NSMutableArray array];
    for (ZKSObject *row in dataSource.records) {
        if (row.checked) {
            [checked addObject:row];
        }
    }
    return checked;
}

-(void)deleteInChunks:(NSArray<ZKSObject*>*)rows start:(NSUInteger)start chunk:(NSUInteger)chunkSize {
    NSUInteger end = MIN(start+chunkSize, rows.count);
    NSString *l = [NSString stringWithFormat:@"Deleting %ld of %ld rows", (unsigned long)end, rows.count];
    self.progress.progressLabel = l;
    NSArray *ids = [[rows subarrayWithRange:NSMakeRange(start, end-start)] valueForKey:@"id"];
    [self.client delete:ids failBlock:^(NSError *result) {
        [[NSAlert alertWithError:result] runModal];
        [self deletesFinished:rows withError:result];
    } completeBlock:^(NSArray *res) {
        [self.results addObjectsFromArray:res];
        if (end == rows.count) {
            // all done, lets wrap up
            [self deletesFinished:rows withError:nil];
        } else {
            [self deleteInChunks:rows start:end chunk:chunkSize];
        }
    }];
}


-(void)deletesFinished:(NSArray<ZKSObject*>*)rows withError:(NSError*)err {
    // save errors to table
    [self.table.wrapper clearErrors];
    NSMutableSet<NSString*> *successIds = [NSMutableSet setWithCapacity:rows.count];
    for (NSUInteger idx = 0; idx < rows.count; idx++) {
        ZKSObject *so = rows[idx];
        if (idx < self.results.count) {
            ZKSaveResult *sr = self.results[idx];
            if (sr.success) {
                [successIds addObject:so.id];
                so.checked = NO;
            } else {
                so.errorMsg = sr.description;
            }
        } else {
            so.errorMsg = err.localizedDescription;
        }
    }
    [self.table removeRowsWithIds:successIds];
    [self.table showHideErrorColumn];
    
    // remove the progress sheet, and tidy up
    [NSApp endSheet:self.progress.progressWindow];
    [self.progress.progressWindow orderOut:self];
     // we're outa here
}

@end
