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

#import <XCTest/XCTest.h>
#import "QueryResultTable.h"

@interface QueryResultTableTest : XCTestCase
@end

@implementation QueryResultTableTest

-(void)testColumnBuilder {
    NSFont *font = [NSFont systemFontOfSize:12];
    ColumnBuilder *b = [[ColumnBuilder alloc] initWithId:@"Name" font:font];
    [b add:@"Eve"];
    [b add:@"Bob"];
    [b add:@"Ann"];
    [b add:@"Eve"];
    [b add:@"Bob"];
    [b add:@"Ann"];
    [b add:@"Turkey"];
    [b add:@"Turkey"];
    [b add:@"A Really Long name"];
    ColumnResult *r = [b resultsWithOffset:2];
    XCTAssertNotNil(r);
    XCTAssertTrue(r.max > r.percentile80);
    XCTAssertTrue(r.headerWidth > 2);
    XCTAssertTrue(r.headerWidth < r.percentile80);
    XCTAssertTrue(r.percentile80 > 2);
    XCTAssertEqualObjects(@"Name", r.identifier);
    XCTAssertEqualObjects(@"Name", r.label);
    XCTAssertEqual(9, r.count);

    // results should be bigger with a bigger font.
    font = [NSFont systemFontOfSize:18];
    b = [[ColumnBuilder alloc] initWithId:@"Name" font:font];
    b.label = @"Header";
    [b add:@"Eve"];
    [b add:@"Bob"];
    [b add:@"Ann"];
    [b add:@"Eve"];
    [b add:@"Bob"];
    [b add:@"Ann"];
    [b add:@"Turkey"];
    [b add:@"Turkey"];
    [b add:@"A Really Long name"];
    ColumnResult *r2 = [b resultsWithOffset:2];
    XCTAssertNotNil(r2);
    XCTAssertTrue(r2.max > r2.percentile80);
    XCTAssertTrue(r2.headerWidth > 2);
    XCTAssertTrue(r2.headerWidth < r2.percentile80);
    XCTAssertTrue(r2.percentile80 > 2);
    XCTAssertTrue(r2.max > r.max);
    XCTAssertTrue(r2.percentile80 > r.percentile80);
    XCTAssertTrue(r2.headerWidth > r.headerWidth);
    XCTAssertEqual(9, r2.count);
    XCTAssertEqualObjects(@"Name", r2.identifier);
    XCTAssertEqualObjects(@"Header", r2.label);
}

-(void)testColumnBuilderCapsLongString {
    ColumnBuilder *b = [[ColumnBuilder alloc] initWithId:@"Desc" font:[NSFont systemFontOfSize:24]];
    [b add:@"one"];
    [b add:@"two"];
    NSMutableString *s = [NSMutableString stringWithCapacity:100];
    while (s.length < 90) {
        [s appendString:@"1234567890"];
    }
    [b add:[s copy]];
    [s appendString:@"1234567890"];
    [b add:[s copy]];
    ColumnResult *r = [b resultsWithOffset:0];
    XCTAssertEqual(r.percentile80, r.max);
    XCTAssertEqual(550, r.max);

    ColumnBuilder *b2 = [[ColumnBuilder alloc] initWithId:@"Desc" font:[NSFont systemFontOfSize:24]];
    [b2 add:@"one"];
    [b2 add:@"two"];
    [s appendString:@"1234567890"];
    [b2 add:[s copy]];
    [s appendString:@"1234567890"];
    [b2 add:[s copy]];
    ColumnResult *r2 = [b2 resultsWithOffset:0];
    XCTAssertEqual(r.max, r2.max);
    XCTAssertEqual(r.percentile80, r2.percentile80);
}

-(void)testCreateColumns {
    NSTableView *tv = [[NSTableView alloc] initWithFrame:NSMakeRect(0, 0, 1500, 500)];
    // These 2 are created by the Nib in the real versions
    [tv addTableColumn:[[NSTableColumn alloc] initWithIdentifier:DELETE_COLUMN_IDENTIFIER]];
    [tv addTableColumn:[[NSTableColumn alloc] initWithIdentifier:ERROR_COLUMN_IDENTIFIER]];
    tv.tableColumns[0].width = 40;
    tv.tableColumns[1].width = 200;
    QueryResultTable *t = [[QueryResultTable alloc] initForTableView:tv];

    NSString *qrXml = @"<QueryResult xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance'>"
                            "<records><type>Account</type><Id>123</Id><Name>Bob</Name>"
                            "<contacts xsi:type='nil' />"
                            "</records>"
                            "<records><type>Account</type><Id>124</Id><Name>Bobby Bobson</Name>"
                            "<contacts xsi:type='QueryResult'>"
                                "<records><type>Contact</type><Id>125</Id><firstName>Eve</firstName></records>"
                                "<size>1</size><done>true</done>"
                            "</contacts>"
                            "</records>"
                            "<size>2</size><done>true</done></QueryResult>";
    ZKElement *xml = [ZKParser parseData:[qrXml dataUsingEncoding:NSUTF8StringEncoding]];
    XCTAssertNotNil(xml);
    ZKQueryResult *qr = [[ZKQueryResult alloc] initWithXmlElement:xml];
    t.queryResult = qr;
    
    XCTAssertEqual(4, tv.tableColumns.count);
    XCTAssertEqualObjects(DELETE_COLUMN_IDENTIFIER, tv.tableColumns[0].identifier);
    XCTAssertEqualObjects(ERROR_COLUMN_IDENTIFIER, tv.tableColumns[1].identifier);
    XCTAssertTrue(tv.tableColumns[1].hidden);
    XCTAssertEqualObjects(@"Name", tv.tableColumns[2].identifier);
    XCTAssertEqualObjects(@"Name", tv.tableColumns[2].title);
    XCTAssertTrue(tv.tableColumns[2].width < 100);
    XCTAssertEqualObjects(@"contacts", tv.tableColumns[3].identifier);
    XCTAssertEqualObjects(@"contacts", tv.tableColumns[3].title);
    // for various reasons, a child QR column will stay sized at 100 unless every row is empty
    XCTAssertTrue(tv.tableColumns[3].width == 100);
}

-(void)testSubsequentQuery {
    NSTableView *tv = [[NSTableView alloc] initWithFrame:NSMakeRect(0, 0, 1500, 500)];
    // These 2 are created by the Nib in the real versions
    [tv addTableColumn:[[NSTableColumn alloc] initWithIdentifier:DELETE_COLUMN_IDENTIFIER]];
    [tv addTableColumn:[[NSTableColumn alloc] initWithIdentifier:ERROR_COLUMN_IDENTIFIER]];
    tv.tableColumns[0].width = 40;
    tv.tableColumns[1].width = 200;
    QueryResultTable *t = [[QueryResultTable alloc] initForTableView:tv];

    NSString *qrXml = @"<QueryResult xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance'>"
                            "<records><type>Account</type><Id>123</Id><Name>Bob</Name>"
                            "</records>"
                            "<records><type>Account</type><Id>124</Id><Name>Bobby Bobson</Name>"
                            "</records>"
                            "<size>2</size><done>true</done></QueryResult>";
    ZKElement *xml = [ZKParser parseData:[qrXml dataUsingEncoding:NSUTF8StringEncoding]];
    XCTAssertNotNil(xml);
    ZKQueryResult *qr = [[ZKQueryResult alloc] initWithXmlElement:xml];
    t.queryResult = qr;
    
    XCTAssertEqual(3, tv.tableColumns.count);
    XCTAssertEqualObjects(DELETE_COLUMN_IDENTIFIER, tv.tableColumns[0].identifier);
    XCTAssertEqualObjects(ERROR_COLUMN_IDENTIFIER, tv.tableColumns[1].identifier);
    XCTAssertTrue(tv.tableColumns[1].hidden);
    XCTAssertEqualObjects(@"Name", tv.tableColumns[2].identifier);
    XCTAssertEqualObjects(@"Name", tv.tableColumns[2].title);
    XCTAssertTrue(tv.tableColumns[2].width < 100);

    qrXml = @"<QueryResult xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance'>"
                            "<records><type>Account</type><Id>123</Id><FirstName>Bob</FirstName><Rating>1</Rating>"
                            "</records>"
                            "<records><type>Account</type><Id>124</Id><FirstName>Bobby Bobson</FirstName><Rating>1</Rating>"
                            "</records>"
                            "<size>2</size><done>true</done></QueryResult>";
    xml = [ZKParser parseData:[qrXml dataUsingEncoding:NSUTF8StringEncoding]];
    XCTAssertNotNil(xml);
    ZKQueryResult *qr2 = [[ZKQueryResult alloc] initWithXmlElement:xml];
    t.queryResult = qr2;
    
    XCTAssertEqual(4, tv.tableColumns.count);
    XCTAssertEqualObjects(DELETE_COLUMN_IDENTIFIER, tv.tableColumns[0].identifier);
    XCTAssertEqualObjects(ERROR_COLUMN_IDENTIFIER, tv.tableColumns[1].identifier);
    XCTAssertTrue(tv.tableColumns[1].hidden);
    XCTAssertEqualObjects(@"FirstName", tv.tableColumns[2].identifier);
    XCTAssertEqualObjects(@"FirstName", tv.tableColumns[2].title);
    XCTAssertTrue(tv.tableColumns[2].width < 100);
    XCTAssertEqualObjects(@"Rating", tv.tableColumns[3].identifier);
    XCTAssertEqualObjects(@"Rating", tv.tableColumns[3].title);
    XCTAssertTrue(tv.tableColumns[3].width < 100);

    t.queryResult = qr;
    XCTAssertEqual(3, tv.tableColumns.count);
    XCTAssertEqualObjects(DELETE_COLUMN_IDENTIFIER, tv.tableColumns[0].identifier);
    XCTAssertEqualObjects(ERROR_COLUMN_IDENTIFIER, tv.tableColumns[1].identifier);
    XCTAssertTrue(tv.tableColumns[1].hidden);
    XCTAssertEqualObjects(@"Name", tv.tableColumns[2].identifier);
    XCTAssertEqualObjects(@"Name", tv.tableColumns[2].title);
    XCTAssertTrue(tv.tableColumns[2].width < 100);
}


-(void)testQueryMoreAddedColumns {
    NSTableView *tv = [[NSTableView alloc] initWithFrame:NSMakeRect(0, 0, 1500, 500)];
    // These 2 are created by the Nib in the real versions
    [tv addTableColumn:[[NSTableColumn alloc] initWithIdentifier:DELETE_COLUMN_IDENTIFIER]];
    [tv addTableColumn:[[NSTableColumn alloc] initWithIdentifier:ERROR_COLUMN_IDENTIFIER]];
    tv.tableColumns[0].width = 40;
    tv.tableColumns[1].width = 200;
    QueryResultTable *t = [[QueryResultTable alloc] initForTableView:tv];

    NSString *qrXml = @"<QueryResult xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance'>"
                            "<records><type>Account</type><Id>123</Id><Name>Bob</Name>"
                            "<owner xsi:type='nil' />"
                            "</records>"
                            "<records><type>Account</type><Id>124</Id><Name>Bobby Bobson</Name>"
                            "<owner xsi:type='nil' />"
                            "</records>"
                            "<size>100</size><done>false</done></QueryResult>";
    ZKElement *xml = [ZKParser parseData:[qrXml dataUsingEncoding:NSUTF8StringEncoding]];
    XCTAssertNotNil(xml);
    ZKQueryResult *qr = [[ZKQueryResult alloc] initWithXmlElement:xml];
    t.queryResult = qr;
    
    XCTAssertEqual(4, tv.tableColumns.count);
    XCTAssertEqualObjects(DELETE_COLUMN_IDENTIFIER, tv.tableColumns[0].identifier);
    XCTAssertEqualObjects(ERROR_COLUMN_IDENTIFIER, tv.tableColumns[1].identifier);
    XCTAssertTrue(tv.tableColumns[1].hidden);
    XCTAssertEqualObjects(@"Name", tv.tableColumns[2].identifier);
    XCTAssertEqualObjects(@"Name", tv.tableColumns[2].title);
    XCTAssertTrue(tv.tableColumns[2].width < 100);
    XCTAssertEqualObjects(@"owner", tv.tableColumns[3].identifier);
    XCTAssertEqualObjects(@"owner", tv.tableColumns[3].title);
    XCTAssertTrue(tv.tableColumns[3].width < 100);
    
    qrXml = @"<QueryResult xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance'>"
                    "<records><type>Account</type><Id>1234</Id><Name>Eve</Name>"
                    "<owner xsi:type='sObject'><type>User</type><Id>1</Id><FirstName>Alice</FirstName><year__c>2020</year__c>"
                    "</owner></records>"
                    "<records><type>Account</type><Id>1244</Id><Name>Bobby Inc.</Name>"
                    "<owner xsi:type='sObject'><type>Group</type><Id>2</Id><Name>SysAdmins</Name>"
                    "</owner></records>"
                    "<size>100</size><done>true</done></QueryResult>";
    xml = [ZKParser parseData:[qrXml dataUsingEncoding:NSUTF8StringEncoding]];
    XCTAssertNotNil(xml);
    qr = [[ZKQueryResult alloc] initWithXmlElement:xml];
    
    [t addQueryMoreResults:qr];
    XCTAssertEqual(6, tv.tableColumns.count);
    XCTAssertEqualObjects(DELETE_COLUMN_IDENTIFIER, tv.tableColumns[0].identifier);
    XCTAssertEqualObjects(ERROR_COLUMN_IDENTIFIER, tv.tableColumns[1].identifier);
    XCTAssertTrue(tv.tableColumns[1].hidden);
    XCTAssertEqualObjects(@"Name", tv.tableColumns[2].identifier);
    XCTAssertEqualObjects(@"Name", tv.tableColumns[2].title);
    XCTAssertTrue(tv.tableColumns[2].width < 100);
    XCTAssertEqualObjects(@"owner.FirstName", tv.tableColumns[3].identifier);
    XCTAssertEqualObjects(@"owner.FirstName", tv.tableColumns[3].title);
    XCTAssertTrue(tv.tableColumns[3].width > 100);
    XCTAssertEqualObjects(@"owner.year__c", tv.tableColumns[4].identifier);
    XCTAssertEqualObjects(@"owner.year__c", tv.tableColumns[4].title);
    XCTAssertTrue(tv.tableColumns[4].width < 100);
    XCTAssertEqualObjects(@"owner.Name", tv.tableColumns[5].identifier);
    XCTAssertEqualObjects(@"owner.Name", tv.tableColumns[5].title);
    XCTAssertTrue(tv.tableColumns[5].width < 100);
}

@end
