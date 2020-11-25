// Copyright (c) 2007,2015,2020 Simon Fell
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

@class ZKSObject;
@class ZKQueryResult;

@protocol EditableQueryResultWrapperDelegate
-(void) dataChangedOnObject:(ZKSObject *)sobject field:(NSString *)fieldName value:(id)value;
-(BOOL) isEditing;
@end

@interface EditableQueryResultWrapper : NSObject<NSTableViewDataSource, NSTableViewDelegate, NSControlTextEditingDelegate> {
    NSCell              *imageCell;
}

-(instancetype)initWithQueryResult:(ZKQueryResult *)qr NS_DESIGNATED_INITIALIZER;
-(instancetype)init NS_UNAVAILABLE;

@property ZKQueryResult     *queryResult;
@property  BOOL              editable;
@property (weak) NSObject<EditableQueryResultWrapperDelegate> *delegate;

@property (readonly) BOOL       hasCheckedRows;
- (void)setChecked:(BOOL)checked onRowWithIndex:(NSUInteger)index;

@property (readonly) BOOL hasErrors;
- (void)clearErrors;
- (void)addError:(NSString *)errMsg onRowWithRowIndex:(NSUInteger)index;

- (BOOL)allowEdit:(NSTableColumn *)aColumn;

// mutate results in place.
- (void)removeRowWithId:(NSString *)recordId;

// pass through to QueryResult
@property (readonly) NSInteger      size;
@property (readonly) BOOL           done;
@property (readonly, copy) NSString *queryLocator;
@property (readonly, copy) NSArray  *records;

@end

@interface EditableQueryResultWrapper (TableColumns)
@property (readonly, copy) NSArray *allSystemColumnIdentifiers;
@end
