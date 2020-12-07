// Copyright (c) 2020 Simon Fell
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

#import <XCTest/XCTest.h>
#import "EditableQueryResultWrapper.h"
#import "SObject.h"

@interface QRWrapperTest : XCTestCase
@property EditableQueryResultWrapper *w;
@end

@implementation QRWrapperTest

-(void)setUp {
    ZKSObject *r1 = [ZKSObject withTypeAndId:@"Account" sfId:@"A"];
    [r1 setFieldValue:@"Bob" field:@"Name"];
    ZKSObject *r2 = [ZKSObject withTypeAndId:@"Account" sfId:@"B"];
    [r2 setFieldValue:@"Eve" field:@"Name"];
    ZKSObject *r3 = [ZKSObject withTypeAndId:@"Account" sfId:@"C"];
    [r3 setFieldValue:@"Alice" field:@"Name"];
    ZKQueryResult *qr = [[ZKQueryResult alloc] initWithRecords:@[r1,r2,r3] size:3 done:YES queryLocator:nil];
    self.w = [[EditableQueryResultWrapper alloc] initWithQueryResult:qr];
}

- (void)testRemoveByIds {
    XCTAssertNotNil(self.w);
    NSUInteger removed = [self.w removeRowsWithIds:[NSSet setWithArray:@[@"B",@"A",@"D"]]];
    XCTAssertEqual(2, removed);
    XCTAssertEqual(1, self.w.queryResult.records.count);
    ZKSObject *x = self.w.queryResult.records[0];
    XCTAssertEqualObjects(@"C",x.id);
}

-(void)testCheckedRows {
    XCTAssertFalse(self.w.hasCheckedRows);
    [self.w.queryResult.records[1] setChecked:YES];
    XCTAssertTrue(self.w.hasCheckedRows);
    [self.w.queryResult.records[1] setChecked:NO];
    XCTAssertFalse(self.w.hasCheckedRows);
    NSTableView *t = [[NSTableView alloc] init];
    [self.w tableView:t didClickTableColumn:[[NSTableColumn alloc] initWithIdentifier:DELETE_COLUMN_IDENTIFIER]];
    XCTAssertTrue(self.w.hasCheckedRows);
    for (ZKSObject *r in self.w.queryResult.records) {
        XCTAssertTrue(r.checked);
    }
    [self.w tableView:t didClickTableColumn:[[NSTableColumn alloc] initWithIdentifier:DELETE_COLUMN_IDENTIFIER]];
    XCTAssertFalse(self.w.hasCheckedRows);
    for (ZKSObject *r in self.w.queryResult.records) {
        XCTAssertFalse(r.checked);
    }
    [self.w tableView:t didClickTableColumn:[[NSTableColumn alloc] initWithIdentifier:@"Bob__c"]];
    XCTAssertFalse(self.w.hasCheckedRows);
}

-(void)testHasErrors {
    XCTAssertFalse(self.w.hasErrors);
    [self.w.records[2] setErrorMsg:@"boom"];
    XCTAssertTrue(self.w.hasErrors);
    [self.w clearErrors];
    XCTAssertFalse(self.w.hasErrors);
    for (ZKSObject *row in self.w.records) {
        XCTAssertNil(row.errorMsg);
    }
}

-(void)testTableDataSource {
    NSTableView *t = [[NSTableView alloc] init];
    XCTAssertEqual(3, [self.w numberOfRowsInTableView:t]);
    NSTableColumn *n = [[NSTableColumn alloc] initWithIdentifier:@"Name"];
    XCTAssertEqualObjects(@"Bob", [self.w tableView:t objectValueForTableColumn:n row:0]);
    XCTAssertEqualObjects(@"Eve", [self.w tableView:t objectValueForTableColumn:n row:1]);
    XCTAssertEqualObjects(@"Alice", [self.w tableView:t objectValueForTableColumn:n row:2]);
    ZKSObject *parent = [ZKSObject withTypeAndId:@"Account" sfId:@"P"];
    [parent setFieldValue:@"Alice Inc." field:@"CompanyName"];
    [self.w.records[2] setFieldValue:parent field:@"Account"];
    NSTableColumn *accName = [[NSTableColumn alloc] initWithIdentifier:@"Account.CompanyName"];
    XCTAssertEqualObjects(@"Alice Inc.", [self.w tableView:t objectValueForTableColumn:accName row:2]);
    XCTAssertNil([self.w tableView:t objectValueForTableColumn:accName row:1]);
    [self.w.records[0] setErrorMsg:@"one"];
    [self.w.records[1] setChecked:YES];
    XCTAssertEqualObjects(@"one", [self.w tableView:t objectValueForTableColumn:[[NSTableColumn alloc] initWithIdentifier:ERROR_COLUMN_IDENTIFIER] row:0]);
    XCTAssertEqualObjects(@TRUE, [self.w tableView:t objectValueForTableColumn:[[NSTableColumn alloc] initWithIdentifier:DELETE_COLUMN_IDENTIFIER] row:1]);
    XCTAssertEqualObjects(@"Account", [self.w tableView:t objectValueForTableColumn:[[NSTableColumn alloc] initWithIdentifier:TYPE_COLUMN_IDENTIFIER] row:2]);
    
    ZKAddress *addr = [[ZKAddress alloc] init];
    addr.state = @"CA";
    NSTableColumn *addrCol = [[NSTableColumn alloc] initWithIdentifier:@"Account.BillingAddress.state"];
    [parent setFieldValue:addr field:@"BillingAddress"];
    XCTAssertEqualObjects(@"CA", [self.w tableView:t objectValueForTableColumn:addrCol row:2]);
    XCTAssertNil([self.w tableView:t objectValueForTableColumn:addrCol row:0]);
}

@end
