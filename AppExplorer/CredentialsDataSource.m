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

#import "CredentialsDataSource.h"
#import "credential.h"
#import "NSArray+Partition.h"
#import "LoginRowViewItem.h"

@interface CredentialsDataSource()
@property (strong) NSArray<Credential*>* creds;
@end

@implementation CredentialsDataSource

-(id)initWithCreds:(NSArray<Credential *> *)creds {
    self = [super init];
    self.creds = creds;
    self.items = [creds partitionByKeyPath:@"server"];
    return self;
}

-(NSInteger)numberOfSectionsInCollectionView:(NSCollectionView *)collectionView {
    return self.items.count;
}

-(NSInteger)collectionView:(nonnull NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.items[section].count;
}

-(NSView *)collectionView:(NSCollectionView *)collectionView viewForSupplementaryElementOfKind:(NSCollectionViewSupplementaryElementKind)kind
              atIndexPath:(NSIndexPath *)indexPath {
    
    NSView *header = [collectionView makeSupplementaryViewOfKind:kind withIdentifier:@"h" forIndexPath:indexPath];
    [header.subviews[0] setStringValue:self.items[indexPath.section][0].server.friendlyHostLabel];
    return header;
}

-(nonnull NSCollectionViewItem *)collectionView:(nonnull NSCollectionView *)collectionView
            itemForRepresentedObjectAtIndexPath:(nonnull NSIndexPath *)indexPath {

    Credential *c = self.items[indexPath.section][indexPath.item];
    LoginRowViewItem *i = [collectionView makeItemWithIdentifier:@"row" forIndexPath:indexPath];
    i.value = c;
    i.btnTitle = c.username;
    i.deletable = self.isEditing;
    i.delegate = self.delegate;
    return i;
}

-(void)removeItem:(Credential*)c {
    NSPredicate *p = [NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        return evaluatedObject != c;
    }];
    self.creds = [self.creds filteredArrayUsingPredicate:p];
    self.items = [self.creds partitionByKeyPath:@"server"];
}

@end
