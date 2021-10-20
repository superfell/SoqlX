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

#import "CredentialsController.h"
#import "credential.h"
#import "NSArray+Partition.h"

@interface CredentialsController()
@property (retain) IBOutlet NSStackView *stack;
@property (retain) NSArray<LoginRowViewItem*>* rows;
@property (assign) BOOL hasSavedCredentials;
@end

@implementation CredentialsController

-(void)reloadData {
    for (NSView *v in self.stack.arrangedSubviews) {
        [v removeFromSuperview];
    }
    NSMutableArray<LoginRowViewItem*>* rows = [NSMutableArray array];
    NSArray<NSArray<Credential*>*>* creds = [[Credential credentialsInMruOrder] partitionByKeyPath:@"server"];
    for (NSArray<Credential*> *serverCreds in creds) {
        
        // header label
        NSTextField *f = [NSTextField labelWithString:serverCreds[0].server.friendlyHostLabel];
        f.font = [NSFont boldSystemFontOfSize:f.font.pointSize];
        [f setContentHuggingPriority:250 forOrientation:NSLayoutConstraintOrientationHorizontal];
        [f addConstraint:[NSLayoutConstraint constraintWithItem:f attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:nil attribute:0 multiplier:1 constant:15]];
        [self.stack addArrangedSubview:f];
        
        // credential buttons
        for (Credential *c in serverCreds) {
            LoginRowViewItem *vi = [[LoginRowViewItem alloc] init];
            vi.value = c;
            vi.title = c.username;
            vi.delegate = self;
            [vi.view setContentHuggingPriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationVertical];
            [vi.view setContentHuggingPriority:100 forOrientation:NSLayoutConstraintOrientationHorizontal];
            [self.stack addArrangedSubview:vi.view];
            [rows addObject:vi];
        }
    }
    self.rows = rows;
    self.hasSavedCredentials = creds.count > 0;
}

-(void)toggleEditing:(id)sender {
    self.isEditing = !self.isEditing;
    for (LoginRowViewItem *i in self.rows) {
        i.deletable = self.isEditing;
    }
}

-(void)loginRowViewItem:(nonnull LoginRowViewItem *)i clicked:(Credential*)value {
    [self.delegate loginRowViewItem:i clicked:value];
}

-(void)loginRowViewItem:(nonnull LoginRowViewItem *)i deleteClicked:(Credential*)value {
    [self.delegate loginRowViewItem:i deleteClicked:value];
    [value deleteEntry];
    [self reloadData];
}

@end
