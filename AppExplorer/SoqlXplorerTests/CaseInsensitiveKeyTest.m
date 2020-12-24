//
//  CaseInsensitiveKeyTest.m
//  SoqlXplorerTests
//
//  Created by Simon Fell on 12/22/20.
//

#import <XCTest/XCTest.h>
#import "CaseInsensitiveStringKey.h"

@interface CaseInsensitiveKeyTest : XCTestCase
@end

@implementation CaseInsensitiveKeyTest

- (void)testIsEqual {
    XCTAssertTrue([[CaseInsensitiveStringKey of:@"BOB"] isEqual:[CaseInsensitiveStringKey of:@"bob"]]);
    XCTAssertTrue([[CaseInsensitiveStringKey of:@"BOB"] isEqual:[CaseInsensitiveStringKey of:@"boB"]]);
    XCTAssertTrue([[CaseInsensitiveStringKey of:@"BOB"] isEqual:[CaseInsensitiveStringKey of:@"bOB"]]);
    XCTAssertFalse([[CaseInsensitiveStringKey of:@"BOB"] isEqual:[CaseInsensitiveStringKey of:@"boa"]]);
    XCTAssertTrue([[CaseInsensitiveStringKey of:@"BOB"] isEqual:@"bob"]);
}

-(void)testCopy {
    // These are immutable, so copyWithZone can return the same instance
    CaseInsensitiveStringKey *k = [CaseInsensitiveStringKey of:@"Bob"];
    CaseInsensitiveStringKey *c = [k copyWithZone:nil];
    XCTAssertTrue([k isEqual:c]);
    XCTAssertTrue(k == c);
}

-(void)testHash {
    CaseInsensitiveStringKey *k = [CaseInsensitiveStringKey of:@"Bob"];
    CaseInsensitiveStringKey *c = [k copyWithZone:nil];
    CaseInsensitiveStringKey *k2 = [CaseInsensitiveStringKey of:@"bob"];
    CaseInsensitiveStringKey *k3 = [CaseInsensitiveStringKey of:@"boa"];
    XCTAssertEqual([k hash], [c hash]);
    XCTAssertEqual([k hash], [k2 hash]);
    XCTAssertNotEqual([k hash], [k3 hash]);
}

-(void)testInDict {
    NSMutableDictionary<CaseInsensitiveStringKey*,NSString*> *d = [[NSMutableDictionary alloc] init];
    CaseInsensitiveStringKey *bob1 = [CaseInsensitiveStringKey of:@"Bob"];
    CaseInsensitiveStringKey *bob2 = [CaseInsensitiveStringKey of:@"BOB"];
    CaseInsensitiveStringKey *eve = [CaseInsensitiveStringKey of:@"Eve"];
    CaseInsensitiveStringKey *even = [CaseInsensitiveStringKey of:@"Even"];
    [d setObject:@"BOB1" forKey:bob1];
    XCTAssertEqualObjects(@"BOB1", [d objectForKey:bob1]);
    XCTAssertEqualObjects(@"BOB1", [d objectForKey:bob2]);
    [d setObject:@"BOB2" forKey:bob2];
    XCTAssertEqual(1, d.count);
    XCTAssertEqualObjects(@"BOB2", [d objectForKey:bob1]);
    XCTAssertEqualObjects(@"BOB2", [d objectForKey:bob2]);
    [d setObject:@"Eve" forKey:eve];
    [d setObject:@"Even" forKey:even];
    XCTAssertEqual(3, d.count);
    XCTAssertEqualObjects(@"BOB2", [d objectForKey:bob1]);
    XCTAssertEqualObjects(@"BOB2", [d objectForKey:bob2]);
    XCTAssertEqualObjects(@"Eve", [d objectForKey:eve]);
    XCTAssertEqualObjects(@"Even", [d objectForKey:even]);
    [d removeObjectForKey:bob1];
    XCTAssertEqual(2, d.count);
    XCTAssertNil([d objectForKey:bob1]);
    XCTAssertNil([d objectForKey:bob2]);
    XCTAssertEqualObjects(@"Eve", [d objectForKey:eve]);
    XCTAssertEqualObjects(@"Even", [d objectForKey:even]);
}

-(void)testInSet {
    NSMutableSet<CaseInsensitiveStringKey*> *s = [[NSMutableSet alloc] init];
    CaseInsensitiveStringKey *bob1 = [CaseInsensitiveStringKey of:@"Bob"];
    CaseInsensitiveStringKey *bob2 = [CaseInsensitiveStringKey of:@"BOB"];
    CaseInsensitiveStringKey *eve = [CaseInsensitiveStringKey of:@"Eve"];
    CaseInsensitiveStringKey *even = [CaseInsensitiveStringKey of:@"Even"];
    [s addObjectsFromArray:@[bob1,bob2,eve,even]];
    XCTAssertEqual(3, s.count);
    XCTAssertTrue([s containsObject:bob1]);
    XCTAssertTrue([s containsObject:bob2]);
    XCTAssertTrue([s containsObject:eve]);
    XCTAssertTrue([s containsObject:even]);
    XCTAssertTrue([s containsObject:[CaseInsensitiveStringKey of:@"bOb"]]);
    XCTAssertFalse([s containsObject:[CaseInsensitiveStringKey of:@"bOba"]]);
}

-(void)testIsImmutable {
    NSMutableString *str = [[NSMutableString alloc] initWithString:@"Bo"];
    CaseInsensitiveStringKey *bo1 = [CaseInsensitiveStringKey of:str];
    [str appendString:@"b"];
    CaseInsensitiveStringKey *bo2 = [CaseInsensitiveStringKey of:@"Bo"];
    XCTAssertTrue([bo2 isEqual:bo1]);
    XCTAssertEqualObjects(@"Bo", [bo1 description]);
}
@end
