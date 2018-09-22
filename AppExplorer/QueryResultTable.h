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

@class ZKQueryResult;
@class EditableQueryResultWrapper;

@interface QueryResultTable : NSObject {
    id                            delegate;
    NSTableView                    *table;
    ZKQueryResult                *queryResult;
    EditableQueryResultWrapper    *wrapper;
}

- (instancetype)initForTableView:(NSTableView *)view NS_DESIGNATED_INITIALIZER;

- (void)removeRowAtIndex:(int)row;

@property (readonly) NSTableView *table;
@property (readonly) EditableQueryResultWrapper *wrapper;
@property (retain) ZKQueryResult *queryResult;
@property (assign) id delegate;

@property (readonly) BOOL hasCheckedRows;
-(void)showHideErrorColumn;
-(void)replaceQueryResult:(ZKQueryResult *)queryResult;    // this is like setQR, except it doesn't reset everything
@end
