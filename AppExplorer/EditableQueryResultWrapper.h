// Copyright (c) 2007,2015 Simon Fell
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
#import <ZKSforce/ZKQueryResult.h>

extern NSString *DELETE_COLUMN_IDENTIFIER;
extern NSString *ERROR_COLUMN_IDENTIFIER;
extern NSArray  *ALL_APP_COLUMN_IDENTIFIERS;

@class ZKSObject;

@protocol EditableQueryResultWrapperDelegate
-(void) dataChangedOnObject:(ZKSObject *)sobject field:(NSString *)fieldName value:(id)value;
-(BOOL) isEditing;
@end

@interface EditableQueryResultWrapper : NSObject<NSTableViewDataSource, NSTableViewDelegate, NSControlTextEditingDelegate> {
    __weak NSObject<EditableQueryResultWrapperDelegate> *delegate;

    ZKQueryResult       *result;
    BOOL                 editable;
    NSCell              *imageCell;
    NSMutableSet        *checkedRows;
    NSMutableDictionary *rowErrors;
}

-(instancetype)initWithQueryResult:(ZKQueryResult *)qr NS_DESIGNATED_INITIALIZER;
-(instancetype)init NS_UNAVAILABLE;

@property (copy) ZKQueryResult *queryResult;
@property  BOOL                 editable;
@property (weak) NSObject<EditableQueryResultWrapperDelegate> *delegate;

@property (readonly) BOOL       hasCheckedRows;
@property (readonly) NSUInteger numCheckedRows;
@property (readonly, copy) NSSet *indexesOfCheckedRows;

- (void)setChecked:(BOOL)checked onRowWithIndex:(NSNumber *)index;

@property (readonly) BOOL hasErrors;
- (void)clearErrors;
- (void)addError:(NSString *)errMsg forRowIndex:(NSNumber *)index;

- (BOOL)allowEdit:(NSTableColumn *)aColumn;

// if you want to make inplace edits to the rows, then create a mutating context, make your changes, then finally call update.
- (id)createMutatingRowsContext;
- (void)remmoveRowAtIndex:(NSInteger)index context:(id)mutatingContext;
- (void)updateRowsFromContext:(id)context;

// pass through to QueryResult
@property (readonly) NSInteger      size;
@property (readonly) BOOL           done;
@property (readonly, copy) NSString *queryLocator;
@property (readonly, copy) NSArray  *records;
// make it compaitble with the data source for a table
//- (int)numberOfRowsInTableView:(NSTableView *)v;
//- (id)tableView:(NSTableView *)view objectValueForTableColumn:(NSTableColumn *)tc row:(int)rowIdx;

@end

@interface EditableQueryResultWrapper (TableColumns)
@property (readonly, copy) NSArray *allSystemColumnIdentifiers;
@end
