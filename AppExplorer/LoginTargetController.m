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

@interface LoginTargetController()
@property (strong) NSArray<LoginTargetItem*>*items;
@end

@implementation LoginTargetController

-(instancetype)init {
    self = [super init];
    NSMutableArray *items = [NSMutableArray arrayWithObjects:
                         [LoginTargetItem itemWithUrl:[NSURL URLWithString:LOGIN_LOGIN]],
                         [LoginTargetItem itemWithUrl:[NSURL URLWithString:LOGIN_TEST]],
                         nil];
    NSArray *servers = [[NSUserDefaults standardUserDefaults] arrayForKey:DEF_SERVERS];
    for (NSString *s in servers) {
        if (([s caseInsensitiveCompare:LOGIN_WWW] == NSOrderedSame) ||
            ([s caseInsensitiveCompare:LOGIN_LOGIN] == NSOrderedSame) ||
            ([s caseInsensitiveCompare:LOGIN_TEST] == NSOrderedSame)) {
            continue;
        }
        LoginTargetItem *i = [LoginTargetItem itemWithUrl:[NSURL URLWithString:s]];
        [items addObject:i];
    }
    self.items = items;
    return self;
}

-(void)awakeFromNib {
    [self.targets registerNib:[[NSNib alloc] initWithNibNamed:@"LoginRowViewItem" bundle:nil] forItemWithIdentifier:@"t"];
    self.targets.dataSource = self;
    [self setPopupHeight];
}

-(void)setPopupHeight {
    NSRect f = self.containerView.frame;
    NSSize vis = self.targets.frame.size;
    NSSize all = self.targets.collectionViewLayout.collectionViewContentSize;
    NSRect new = f;
    new.size.height = f.size.height - vis.height + all.height;
    self.containerView.frame = new;
    // TODO, no doubt I'll be made to regret this at some point.
    [[self.containerView.window valueForKey:@"_popover"] setContentSize:new.size];
}

-(void)setDefaultsFromItems {
    NSArray *servers = [self.items valueForKeyPath:@"url.absoluteString"];
    [[NSUserDefaults standardUserDefaults] setObject:servers forKey:DEF_SERVERS];
}

-(IBAction)toggleEditing:(id)sender {
    self.isEditing = !self.isEditing;
    if (!self.isEditing) {
        for (LoginTargetItem *i in self.items) {
            i.deletable = FALSE;
        }
    } else {
        for (LoginTargetItem *i in self.items) {
            i.deletable = !i.url.isStandardEndpoint;
        }
    }
}

-(IBAction)addNewUrl:(id)sender {
    NSString *u = self.url.stringValue;
    if (u.length > 0) {
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@.my.salesforce.com", u]];
        NSArray *existing = [self.items filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"url=%@", url]];
        if (existing.count > 0) {
            NSAlert *a = [[NSAlert alloc] init];
            a.alertStyle = NSAlertStyleWarning;
            a.messageText = @"Already Exists";
            a.informativeText = @"The entered URL is already in the list";
            [a runModal];
            return;
        }
        LoginTargetItem *i = [LoginTargetItem itemWithUrl:url];
        i.deletable = TRUE;
        self.items = [self.items arrayByAddingObject:i];
        [self setDefaultsFromItems];
        [self.targets reloadData];
        [self setPopupHeight];
    } else {
        NSAlert *a = [[NSAlert alloc] init];
        a.alertStyle = NSAlertStyleWarning;
        a.messageText = @"Invalid URL";
        a.informativeText = @"Please enter the name of the organizations custom domain name.";
        [a runModal];
    }
}

-(nonnull NSCollectionViewItem *)collectionView:(nonnull NSCollectionView *)collectionView
             itemForRepresentedObjectAtIndexPath:(nonnull NSIndexPath *)indexPath {

    LoginRowViewItem *i = [collectionView makeItemWithIdentifier:@"t" forIndexPath:indexPath];
    LoginTargetItem *target = self.items[indexPath.item];
    i.value = target;
    i.btnTitle = target.url.friendlyHostLabel;
    i.deletable = target.deletable;
    i.delegate = self;
    return i;
}

-(NSInteger)collectionView:(nonnull NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.items.count;
}

-(void)loginRowViewItem:(LoginRowViewItem *)i deleteClicked:(LoginTargetItem*)item {
    self.items = [self.items filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"url != %@", item.url]];
    [self.targets reloadData];
    [self setPopupHeight];
    [self setDefaultsFromItems];
}

-(void)loginRowViewItem:(LoginRowViewItem *)i clicked:(id)item {
    [self.delegate loginTargetSelected:item];
}

@end
