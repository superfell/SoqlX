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
#import "QueryColumns.h"
#import <ZKSforce/ZKQueryResult.h>
#import <ZKSforce/ZKSObject.h>
#import <ZKSforce/ZKParser.h>

@interface QueryColumnsTest : XCTestCase

@end

@implementation QueryColumnsTest

- (void)testNoNullsNoNestedResults {
    ZKSObject *o = [ZKSObject withType:@"Account"];
    [o setFieldValue:@"Eve" field:@"FirstName"];
    [o setFieldValue:@"Alice" field:@"Friend__c"];
    ZKQueryResult *qr = [[ZKQueryResult alloc] initWithRecords:@[o] size:1 done:YES queryLocator:nil];
    QueryColumns *qc = [[QueryColumns alloc] initWithResult:qr];
    XCTAssertFalse(qc.isSearchResult);
    XCTAssertEqualObjects((@[@"FirstName",@"Friend__c"]), qc.names);
}

- (void)testNoNullsNoNestedResultsPreservesOrder {
    ZKSObject *o = [ZKSObject withType:@"Account"];
    [o setFieldValue:@"Alice" field:@"Friend__c"];
    [o setFieldValue:@"Eve" field:@"FirstName"];
    ZKQueryResult *qr = [[ZKQueryResult alloc] initWithRecords:@[o] size:1 done:YES queryLocator:nil];
    QueryColumns *qc = [[QueryColumns alloc] initWithResult:qr];
    XCTAssertFalse(qc.isSearchResult);
    XCTAssertEqualObjects((@[@"Friend__c",@"FirstName"]), qc.names);
}

- (void)testSingleNestedSObject {
    ZKSObject *con = [ZKSObject withType:@"Contact"];
    [con setFieldValue:@"Bob" field:@"Name"];
    [con setFieldValue:@TRUE field:@"IsSalesPerson"];
    ZKSObject *acc = [ZKSObject withType:@"Account"];
    [acc setFieldValue:@"Eve" field:@"FirstName"];
    [acc setFieldValue:con field:@"Salesperson__c"];
    [acc setFieldValue:@"Alice" field:@"Friend__c"];
    ZKQueryResult *qr = [[ZKQueryResult alloc] initWithRecords:@[acc] size:1 done:YES queryLocator:nil];
    QueryColumns *qc = [[QueryColumns alloc] initWithResult:qr];
    XCTAssertFalse(qc.isSearchResult);
    XCTAssertEqualObjects((@[@"FirstName",@"Salesperson__c.Name",@"Salesperson__c.IsSalesPerson",@"Friend__c"]), qc.names);
}

- (void)testDoubleNestedSObject {
    ZKSObject *usr = [ZKSObject withType:@"User"];
    [usr setFieldValue:@"superfell" field:@"Nickname"];
    ZKSObject *con = [ZKSObject withType:@"Contact"];
    [con setFieldValue:@"Bob" field:@"Name"];
    [con setFieldValue:@TRUE field:@"IsSalesPerson"];
    [con setFieldValue:usr field:@"CreatedBy"];
    ZKSObject *acc = [ZKSObject withType:@"Account"];
    [acc setFieldValue:@"Eve" field:@"FirstName"];
    [acc setFieldValue:con field:@"Salesperson__c"];
    [acc setFieldValue:@"Alice" field:@"Friend__c"];
    ZKQueryResult *qr = [[ZKQueryResult alloc] initWithRecords:@[acc] size:1 done:YES queryLocator:nil];
    QueryColumns *qc = [[QueryColumns alloc] initWithResult:qr];
    XCTAssertFalse(qc.isSearchResult);
    XCTAssertEqualObjects((@[@"FirstName",@"Salesperson__c.Name",@"Salesperson__c.IsSalesPerson",@"Salesperson__c.CreatedBy.Nickname",@"Friend__c"]), qc.names);
}

-(void)testNestedSObjectWithNil {
    // When there's a nested (related) SObject whose value is null, we can't work out which columns were
    // selected from that related object until we find a row with a non-null value. Check that the QueryColumns
    // goes through all the results until it has seen enough values to be sure its got all the column names of
    // related sobjects.
    
    // Its not possible via the ZKSObject API to construct a ZKSObject with a nil value in the same manner
    // that parsing an API response does. So for this test, we need to construct our input by parsing some XML.
    NSString *qrXml = @"<QueryResult xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance'>"
                        "<records><type>Account</type><Id>123</Id><firstName>Bob</firstName><Salesperson xsi:nil='true' /></records>"
                        "<records><type>Account</type><Id>124</Id><firstName>Alice</firstName>"
                            "<Salesperson xsi:type='sObject'><type>User</type><Id>321</Id><name>Eve</name></Salesperson></records>"
                        "<size>2</size><done>true</done></QueryResult>";
    ZKElement *xml = [ZKParser parseData:[qrXml dataUsingEncoding:NSUTF8StringEncoding]];
    XCTAssertNotNil(xml);
    ZKQueryResult *qr = [[ZKQueryResult alloc] initWithXmlElement:xml];
    QueryColumns *qc = [[QueryColumns alloc] initWithResult:qr];
    XCTAssertFalse(qc.isSearchResult);
    XCTAssertEqualObjects((@[@"firstName",@"Salesperson.name"]), qc.names);
}

-(void)testNestedSObjectsWithNullOtherColumn {
    // see https://github.com/superfell/SoqlX/issues/92
    // a query specifies a double nested related object, and a top level column where the nested sobjects are populated and the top level column is null.
    // this should only add the nested sobject columns once, not each row.
    NSString *qrXml = @"<QueryResult xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance'>"
                        "<records><type>Account</type><Id>123</Id><firstName>Bob</firstName>"
                            "<Salesperson xsi:type='sObject'><type>User</type><Id>321</Id><name>Eve</name>"
                                "<CreatedBy xsi:type='sObject'><type>User</type><Id>444</Id><Nickname>superfell</Nickname></CreatedBy></Salesperson>"
                            "<Website xsi:nil='true' /></records>"
                        "<records><type>Account</type><Id>124</Id><firstName>Alice</firstName>"
                            "<Salesperson xsi:type='sObject'><type>User</type><Id>321</Id><name>Eve</name>"
                                "<CreatedBy xsi:type='sObject'><type>User</type><Id>444</Id><Nickname>superfell</Nickname></CreatedBy></Salesperson>"
                            "<Website xsi:nil='true' /></records>"
                        "<size>2</size><done>true</done></QueryResult>";
    ZKElement *xml = [ZKParser parseData:[qrXml dataUsingEncoding:NSUTF8StringEncoding]];
    XCTAssertNotNil(xml);
    ZKQueryResult *qr = [[ZKQueryResult alloc] initWithXmlElement:xml];
    QueryColumns *qc = [[QueryColumns alloc] initWithResult:qr];
    XCTAssertFalse(qc.isSearchResult);
    XCTAssertEqualObjects((@[@"firstName",@"Salesperson.name",@"Salesperson.CreatedBy.Nickname",@"Website"]), qc.names);
}

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}


@end
