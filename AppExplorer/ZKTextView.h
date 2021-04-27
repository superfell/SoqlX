// Copyright (c) 2016 Simon Fell
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

@class ZKTextView;
@protocol ZKTextViewCompletion;

typedef BOOL (^CompletionCallback)(ZKTextView*,id<ZKTextViewCompletion>);

@protocol ZKTextViewCompletion
-(NSString*)displayText;
-(NSString*)nonFinalInsertionText;
-(NSString*)finalInsertionText;
-(CompletionCallback)onFinalInsert;
-(NSImage*)icon;
@end

@protocol ZKTextViewDelegate <NSTextViewDelegate>
-(NSArray<id<ZKTextViewCompletion>>*)textView:(NSTextView *)textView completionsForPartialWordRange:(NSRange)charRange;
@end

@interface ZKTextView : NSTextView<NSTableViewDataSource, NSTableViewDelegate> {
    uint64_t lastEvent;
    BOOL hasTyped;
}
@property  (strong,nonatomic) IBOutlet NSViewController *pv;
@property  (strong,nonatomic) IBOutlet NSPopover *po;
@property  (strong,nonatomic) IBOutlet NSTableView *table;
@property  (strong,nonatomic) IBOutlet NSScrollView *tableScollView;

-(IBAction)completionDoubleClicked:(id)sender;

@end
