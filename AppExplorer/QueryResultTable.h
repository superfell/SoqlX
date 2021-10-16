// Copyright (c) 2008 Simon Fell
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
//
// This class wraps a QueryResult/EditableQueryResultsWrapper/NSTableView trifecta
//

#import <Cocoa/Cocoa.h>
#import "SObjectSortDescriptor.h"

@class ZKQueryResult;
@class EditableQueryResultWrapper;

@interface QueryResultTable : NSObject {
    id                           __weak delegate;
    NSTableView                  *__weak table;
    EditableQueryResultWrapper   *wrapper;
}

- (instancetype)initForTableView:(NSTableView *)view NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (void)removeRowsWithIds:(NSSet<NSString*> *)recordIds;

@property (weak, readonly) NSTableView *table;
@property (weak, readonly) EditableQueryResultWrapper *wrapper;
@property (strong) ZKQueryResult *queryResult;
@property (weak) id delegate;
@property describeProvider describer;

@property (readonly) BOOL hasCheckedRows;

-(void)showHideErrorColumn;
-(void)addQueryMoreResults:(ZKQueryResult *)queryResult;

@end

// These are exposed just for testing, otherwise they are internal to QueryResultTable
@interface ColumnResult : NSObject
@property (assign) NSInteger count;
@property (assign) NSInteger max;
@property (assign) NSInteger percentile80;
@property (assign) NSInteger headerWidth;
@property (assign) NSInteger width;
@property (retain) NSString *identifier;
@property (retain) NSString *label;
@end

@interface ColumnBuilder : NSObject {
    NSMutableString             *buffer;
    NSMutableArray<NSNumber*>   *vals;
    NSInteger                   minToConsider;
    NSInteger                   minCount;
    NSInteger                   headerWidth;
}
@property (retain) NSFont *font;
@property (retain) NSString *identifier;
@property (retain) NSString *label;
@property (assign) NSInteger width;

-(instancetype)initWithId:(NSString*)i font:(NSFont*)f NS_DESIGNATED_INITIALIZER;
-(instancetype)init NS_UNAVAILABLE;

-(void)add:(NSString *)s;
-(ColumnResult*)resultsWithOffset:(NSInteger)pad;

@end
