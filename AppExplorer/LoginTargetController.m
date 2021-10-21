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

#import "LoginTargetController.h"
#import "Defaults.h"
#import "credential.h"

// See note in ZKLoginController for why this exists, and is not just on
// LoginTargetController directly.
@interface LoginTargetControllerState : NSObject
// for the add domain widget
@property (retain) NSString *domain;
@property (readonly) NSString *populatedDomain;
@end

@interface LoginTargetController()
@property (retain) IBOutlet NSStackView *stack;
@property (retain) IBOutlet NSView      *addUrlView;
@property (retain) IBOutlet NSLayoutConstraint *editConstraint;
@property (retain) IBOutlet LoginTargetControllerState *state;

@property (retain) NSMutableArray<NSURL*>*items;
@property (retain) NSMutableArray<LoginRowViewItem*>*rows;

@end

@implementation LoginTargetControllerState

+(NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
    NSSet *paths = [super keyPathsForValuesAffectingValueForKey:key];
    if ([key isEqualToString:@"populatedDomain"]) {
        return [paths setByAddingObject:@"domain"];
    }
    return paths;
}
-(void)awakeFromNib {
    self.domain = @"";
}
-(NSString*)populatedDomain {
    return [NSString stringWithFormat:@"https://%@.my.salesforce.com", self.domain == nil ? @"" : self.domain];
}
@end

@implementation LoginTargetController

-(instancetype)init {
    self = [super init];
    NSMutableArray<NSURL*> *items = [NSMutableArray arrayWithObjects:
                         [NSURL URLWithString:LOGIN_LOGIN],
                         [NSURL URLWithString:LOGIN_TEST],
                         nil];
    NSArray *servers = [[NSUserDefaults standardUserDefaults] arrayForKey:DEF_SERVERS];
    for (NSString *s in servers) {
        if (([s caseInsensitiveCompare:LOGIN_WWW] == NSOrderedSame) ||
            ([s caseInsensitiveCompare:LOGIN_LOGIN] == NSOrderedSame) ||
            ([s caseInsensitiveCompare:LOGIN_TEST] == NSOrderedSame)) {
            continue;
        }
        NSURL *url = [NSURL URLWithString:s];
        [items addObject:url];
    }
    self.items = items;
    return self;
}

-(void)dealloc {
    NSLog(@"LoginTargetController dealloc");
}

-(void)awakeFromNib {
    self.addUrlView.hidden = YES;
    self.editConstraint.priority = 999;
}

-(LoginRowViewItem*)makeItem:(NSURL*)url {
    LoginRowViewItem<NSURL*> *vi = [[LoginRowViewItem alloc] init];
    vi.value = url;
    vi.title = url.friendlyHostLabel;
    vi.delegate = self;
    vi.deletable = self.isEditing && (!url.isStandardEndpoint);
    return vi;
}

-(void)reloadData {
    for (NSView *v in self.stack.arrangedSubviews) {
        [v removeFromSuperview];
    }
    NSMutableArray *rows = [NSMutableArray arrayWithCapacity:self.items.count];
    for (NSURL *url in self.items) {
        LoginRowViewItem<NSURL*> *vi = [self makeItem:url];
        [self.stack addArrangedSubview:vi.view];
        [rows addObject:vi];
    }
    self.rows = rows;
}

-(void)setDefaultsFromItems {
    NSArray *servers = [self.items valueForKey:@"absoluteString"];
    [[NSUserDefaults standardUserDefaults] setObject:servers forKey:DEF_SERVERS];
}

-(IBAction)toggleEditing:(id)sender {
    self.isEditing = !self.isEditing;
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull ctx) {
        ctx.duration = 0.25;
        ctx.allowsImplicitAnimation = YES;
        for (LoginRowViewItem<NSURL*>* row in self.rows) {
            row.deletable = self.isEditing && (!row.value.isStandardEndpoint);
        }
        self.addUrlView.hidden = !self.isEditing;
        self.editConstraint.priority = self.isEditing ? 333 : 999;
        [self.stack.superview layoutSubtreeIfNeeded];
    }];
}

-(IBAction)addNewUrl:(id)sender {
    if (!self.isEditing) {
        // the text field submits when it gets hidden if it has focus
        // (guess it submits on loss of focus). So skip those.
        return;
    }
    if (self.state.domain.length > 0) {
        NSURL *url = [NSURL URLWithString:self.state.populatedDomain];
        NSUInteger existingIdx = [self.items indexOfObject:url];
        if (existingIdx != NSNotFound) {
            NSAlert *a = [[NSAlert alloc] init];
            a.alertStyle = NSAlertStyleWarning;
            a.messageText = @"Already Exists";
            a.informativeText = @"The entered URL is already in the list";
            [a runModal];
            return;
        }
        [self.items addObject:url];
        [self setDefaultsFromItems];
        LoginRowViewItem*row = [self makeItem:url];
        NSLog(@"created new row %@ %@ %p", row.class, row, row);
        [self.stack addArrangedSubview:row.view];
        [self.rows addObject:row];
    } else {
        NSAlert *a = [[NSAlert alloc] init];
        a.alertStyle = NSAlertStyleWarning;
        a.messageText = @"Invalid URL";
        a.informativeText = @"Please enter the name of the organizations custom domain name.";
        [a runModal];
    }
}

-(void)loginRowViewItem:(LoginRowViewItem *)i deleteClicked:(NSURL*)item {
    [self.items removeObject:item];
    [self setDefaultsFromItems];
    NSUInteger rowIdx = [self.rows indexOfObjectPassingTest:^BOOL(LoginRowViewItem * _Nonnull r, NSUInteger idx, BOOL * _Nonnull stop) {
        return [r.value isEqual:item];
    }];
    if (rowIdx != NSNotFound) {
        // This will animate the view out of the stack.
        self.rows[rowIdx].view.hidden = YES;
        [self.rows removeObjectAtIndex:rowIdx];
    } else {
        NSLog(@"server %@ deleted, but not found in rows", item.friendlyHostLabel);
    }
}

-(void)loginRowViewItem:(LoginRowViewItem *)i clicked:(NSURL*)item {
    [self.delegate loginTargetSelected:item];
}

@end
