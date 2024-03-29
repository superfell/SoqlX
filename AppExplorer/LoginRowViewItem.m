// Copyright (c) 2021 Simon Fell
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

#import "LoginRowViewItem.h"
#import "credential.h"
#import "Defaults.h"

@interface LoginRowViewItem ()
-(IBAction)click:(id)sender;
-(IBAction)deleteItem:(id)sender;
@property (retain) IBOutlet NSButton *button;
@property (retain) IBOutlet NSLayoutConstraint *delWidthConstraint;
@property (assign) BOOL isDeletable;
@end

@implementation LoginRowViewItem

-(instancetype)init {
    self = [super init];
    NSNib *rowNib = [[NSNib alloc] initWithNibNamed:@"LoginRowViewItem" bundle:nil];
    [rowNib instantiateWithOwner:self topLevelObjects:nil];
    return self;
}

-(void)dealloc {
    NSLog(@"LoginRowViewItem dealloc");
}

-(void)awakeFromNib {
    self.delWidthConstraint.constant = 0;
    self.isDeletable = NO;
}

-(void)setTitle:(NSString*)t {
    self.button.title = t;
}
-(NSString*)title {
    return self.button.title;
}

-(void)setDeletable:(BOOL)deletable {
    self.isDeletable = deletable;
    self.delWidthConstraint.constant = deletable ? 24 : 0;
    [self.view layoutSubtreeIfNeeded];
}

-(BOOL)deletable {
    return self.isDeletable;
}

-(void)click:(id)sender {
    if (self.delegate) {
        [self.delegate loginRowViewItem:self clicked:self.value];
    }
}

-(void)deleteItem:(id)sender {
    if (self.delegate) {
        [self.delegate loginRowViewItem:self deleteClicked:self.value];
    }
}

@end
