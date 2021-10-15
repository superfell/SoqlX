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
#import "SObject.h"

@interface SObjectTest : XCTestCase
@end

@implementation SObjectTest

-(void)testChecked {
    ZKSObject *o = [ZKSObject withType:@"Task"];
    XCTAssertFalse(o.checked);
    o.checked = YES;
    XCTAssertTrue(o.checked);
}

-(void)testErrorMessage {
    ZKSObject *o = [ZKSObject withType:@"Task"];
    XCTAssertNil(o.errorMsg);
    o.errorMsg = @"boom";
    XCTAssertEqualObjects(@"boom", o.errorMsg);
}

-(void)testValueForFieldPathArray {
    // acount -> owner -> createdBy
    ZKSObject *creator = [ZKSObject withType:@"User"];
    [creator setFieldValue:@"Bob" field:@"FirstName"];
    [creator setFieldValue:@"Bobson" field:@"LastName"];
    ZKSObject *owner = [ZKSObject withType:@"User"];
    [owner setFieldValue:@"Alice" field:@"FirstName"];
    [owner setFieldValue:creator field:@"CreatedBy"];
    ZKSObject *acc = [ZKSObject withType:@"Account"];
    [acc setFieldValue:@"Eve Inc." field:@"Name"];
    [acc setFieldValue:@"12" field:@"NumberOfEmployees"];
    [acc setFieldValue:owner field:@"Owner"];
    
    XCTAssertEqualObjects(@"Eve Inc.", [acc valueForFieldPathArray:@[@"Name"]]);
    XCTAssertEqualObjects(@"12", [acc valueForFieldPathArray:@[@"NumberOfEmployees"]]);
    XCTAssertNil([acc valueForFieldPathArray:@[@"Missing"]]);
    XCTAssertEqualObjects(@"Alice", ([acc valueForFieldPathArray:@[@"Owner",@"FirstName"]]));
    XCTAssertEqualObjects(@"Bob", ([acc valueForFieldPathArray:@[@"Owner", @"CreatedBy", @"FirstName"]]));
    XCTAssertNil(([acc valueForFieldPathArray:@[@"Owner",@"Missing"]]));
    XCTAssertNil(([acc valueForFieldPathArray:@[@"Missing",@"Owner"]]));
}

@end
