// Copyright (c) 2006,2014,2016,2018,2019,2020 Simon Fell
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

#import "Describer.h"
#import "CaseInsensitiveStringKey.h"

@interface Describer ()
@property NSMutableDictionary<CaseInsensitiveStringKey*,ZKDescribeSObject*> *describes;
@property NSMutableSet<CaseInsensitiveStringKey*> *priorityDescribes;

-(void)startBackgroundDescribesOf:(NSArray<CaseInsensitiveStringKey*>*)sobjectNames
                       withClient:(ZKSforceClient*)c
                      andDelegate:(NSObject<DescriberDelegate> *)delegate;
@end

@implementation  Describer

-(void)describe:(ZKDescribeGlobalTheme*)theme withClient:(ZKSforceClient*)c andDelegate:(NSObject<DescriberDelegate> *)delegate {
    self.priorityDescribes = [[NSMutableSet alloc] init];
    self.describes = [[NSMutableDictionary alloc] init];
    stopBackgroundDescribes = 0;
    NSArray *neededDescribes = [[theme.global.sobjects valueForKey:@"name"]
                                sortedArrayUsingDescriptors:@[[NSSortDescriptor
                                                               sortDescriptorWithKey:@"description"
                                                               ascending:NO
                                                               selector:@selector(caseInsensitiveCompare:)]]];
    NSMutableArray<CaseInsensitiveStringKey*> *describeKeys = [NSMutableArray arrayWithCapacity:neededDescribes.count];
    for (NSString *n in neededDescribes) {
        [describeKeys addObject:[CaseInsensitiveStringKey of:n]];
    }
    [self startBackgroundDescribesOf:describeKeys withClient:c andDelegate:delegate];
}

-(void)prioritize:(NSString *)name {
    CaseInsensitiveStringKey *key = [CaseInsensitiveStringKey of:name];
    if (![self.priorityDescribes containsObject:key]) {
        // priorityDescribes is a set, so this containsObject check is not neccassary, but
        // it does result in the following log only getting recorded once instead of many
        // times. (as the row sorter can end up calling prioritize for every single row)
        NSLog(@"Prioritizing describe of %@", name);
        [self.priorityDescribes addObject:key];
    }
}

-(void)stop {
    atomic_fetch_add(&stopBackgroundDescribes, 1);
}

-(void)startBackgroundDescribesOf:(NSArray<CaseInsensitiveStringKey*>*)toDescribe
                       withClient:(ZKSforceClient*)sforce
                      andDelegate:(NSObject<DescriberDelegate> *)delegate {

    NSArray<CaseInsensitiveStringKey*> __block *leftTodo = toDescribe;
    NSMutableDictionary<CaseInsensitiveStringKey*, NSNumber*> __block *errors = [[NSMutableDictionary alloc] init];

    // allow for the batch size to get halved all the way to one, and then allow a few more attempts
    const int MAX_ERRORS_BEFORE_GIVING_UP = 10;
    const int DEFAULT_DESC_BATCH = 16;
    int __block batchSize = DEFAULT_DESC_BATCH;
    typedef void (^nextBlock)(void);
    nextBlock __block describeNextBatch;
    
    describeNextBatch = ^{
        if (leftTodo.count == 0 || (atomic_fetch_add(&self->stopBackgroundDescribes, 0) > 0)) {
            NSLog(@"Background describes completed");
            // sanity check we got everything
            if (toDescribe.count != self.describes.count) {
                NSLog(@"Background describe finished, but there are still missing describes");
                for (CaseInsensitiveStringKey *k in toDescribe) {
                    if (self.describes[k] == nil) {
                        NSLog(@"\t%@", k);
                    }
                }
            }
            describeNextBatch = nil;
            return;
        }
        NSMutableArray<CaseInsensitiveStringKey*> *batch = [NSMutableArray arrayWithCapacity:batchSize];
        NSMutableArray<CaseInsensitiveStringKey*> *priority = [[NSMutableArray alloc] init];
        for (CaseInsensitiveStringKey *name in self.describes.allKeys) {
            [self.priorityDescribes removeObject:name];
        }
        for (CaseInsensitiveStringKey *item in self.priorityDescribes) {
            [priority addObject:item];
            if (priority.count >= batchSize) {
                break;
            }
        }
        if (priority.count > 0) {
            NSLog(@"Found priority describes for %@", priority);
        }
        [batch addObjectsFromArray:priority];
        NSInteger i;
        for (i=leftTodo.count-1; i >= 0 && batch.count < batchSize; i--) {
            CaseInsensitiveStringKey *item = leftTodo[i];
            if (    ([self.describes objectForKey:item] != nil)
                    || ([errors[item] intValue] >= MAX_ERRORS_BEFORE_GIVING_UP)
                    || ([priority containsObject:item])
                ) {
                continue;
            }
            [batch addObject:item];
        }
        if (batch.count > 0) {
            NSLog(@"Describing %lu sobjects (%lu with priority)", (unsigned long)batch.count, (unsigned long)priority.count);
            [sforce describeSObjects:[batch valueForKey:@"value"] failBlock:^(NSError *err) {
                NSLog(@"Failed to describe %@: %@", batch, err);
                for (CaseInsensitiveStringKey *failedSObject in batch) {
                    int count = [errors[failedSObject] intValue] + 1;
                    errors[failedSObject] = @(count);
                    if (count >= MAX_ERRORS_BEFORE_GIVING_UP) {
                        [delegate describe:failedSObject.value failed:err];
                    }
                }
                batchSize = MAX(1, batchSize / 2);
                describeNextBatch();
            } completeBlock:^(NSArray *result) {
                for (ZKDescribeSObject *o in result) {
                    [self.describes setObject:o forKey:[CaseInsensitiveStringKey of:o.name]];
                }
                for (CaseInsensitiveStringKey *sobject in batch) {
                    [errors removeObjectForKey:sobject];
                    [self.priorityDescribes removeObject:sobject];
                }
                [delegate described:result];
                batchSize = MIN(DEFAULT_DESC_BATCH, MAX(2, batchSize * 3/2));
                leftTodo = [leftTodo subarrayWithRange:NSMakeRange(0, i+1)];
                describeNextBatch();
            }];
        } else {
            // ensure the complete sanity check is done.
            leftTodo = [leftTodo subarrayWithRange:NSMakeRange(0, i+1)];
            describeNextBatch();
        }
    };
    describeNextBatch();
}

@end
