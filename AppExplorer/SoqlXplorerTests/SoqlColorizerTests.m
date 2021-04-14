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
#import <ZKSforce/ZKSforce.h>
#import "SoqlColorizer.h"

@interface SoqlColorizerTests : XCTestCase

@end

@implementation SoqlColorizerTests

describer descs;

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    ZKDescribeField *fAccount = [ZKDescribeField new];
    fAccount.referenceTo = @[@"Account"];
    fAccount.name = @"AccountId";
    fAccount.relationshipName = @"Account";
    fAccount.namePointing = NO;
    ZKDescribeField *fName = [ZKDescribeField new];
    fName.name = @"Name";
    ZKDescribeSObject *contact = [ZKDescribeSObject new];
    contact.name = @"Contact";
    contact.fields = @[fAccount,fName];
    
    ZKDescribeSObject *account = [ZKDescribeSObject new];
    account.name = @"Account";
    account.fields = @[fName];
    ZKChildRelationship *contacts = [ZKChildRelationship new];
    contacts.childSObject = @"Contact";
    contacts.relationshipName = @"Contacts";
    account.childRelationships = @[contacts];
    
    descs = ^ZKDescribeSObject*(NSString *n) {
        if ([n caseInsensitiveCompare:@"account"] == NSOrderedSame) {
            return account;
        }
        if ([n caseInsensitiveCompare:@"contact"] == NSOrderedSame) {
            return contact;
        }
        return nil;
    };
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

typedef struct {
    SoqlTokenType token;
    NSRange loc;
} TokenPos;

-(NSString *)tokenName:(SoqlTokenType)t {
    switch (t) {
        case TKeyword: return @"Keyword";
        case TField: return @"Field";
        case TFunc: return @"Func";
        case TLiteral: return @"Literal";
        case TError: return @"Error";
    }
}

- (void)testColorTokens {
    NSArray<NSString*>* queries = @[
        @"select name from account where name='bob'",
        @"select namer from account where name='bob'",
        @"select name from case where LastModifiedDate >= YESTERDAY",
        @"select name from case c",
        @"select id,(select name from contacts),name from account where name in ('bob','eve','alice')",
        @"select name from account where id in (select accountId from contact)",
        @"select account.city from contact where name LIKE 'b%'",
        @"select account.city from contact where name LIKE 'b%' OR name='eve'",
        @"select c.account.city from contact c where name LIKE 'b%'",
        @"select (select c.name from contacts c),name from account a where a.name>='bob'",
        @"select account.name from account where name > 'bob'",
        @"select a.name from account a where name > 'bob'",
        @"select max(name) from account where CALENDARY_YEAR(createdDate) > 2018",
        // example from https://developer.salesforce.com/docs/atlas.en-us.soql_sosl.meta/soql_sosl/sforce_api_calls_soql_alias.htm
        @"SELECT count() FROM Contact c, c.Account a WHERE a.name = 'MyriadPubs'",
        // a less convoluted example of the same query
        @"SELECT count() FROM Contact WHERE account.name = 'Salesforce.com'",
        // more related convoluted examples, described in SoqlColorizer
        @"SELECT count() FROM Contact c, c.Account a, a.CreatedBy u WHERE u.alias = 'Sfell'",
        @"SELECT count() FROM Contact c, a.CreatedBy u, c.Account a WHERE u.alias = 'Sfell'",
        @"SELECT count() FROM Contact c, c.CreatedBy u, c.Account a WHERE u.alias = 'Sfell' and a.Name > 'a'",
        @"SELECT count() FROM Contact x, x.Account.CreatedBy u, x.CreatedBy a WHERE u.alias = 'Sfell' and a.alias='Sfell'",
        @"SELECT x.name FROM Contact x, x.Account.CreatedBy u, x.CreatedBy a WHERE u.alias = 'Sfell' and (a.alias='Sfell' or x.MailingCity IN('SF','LA'))order by x.name desc nulls first",
        @"SELECT account.name.name FROM account",
        @"SELECT name FROM contact order by name asc",
        @"SELECT name FROM contact order by name asc nulls last",
        @"SELECT name FROM contact order by name asc nulls last, account.name desc",
        @"SELECT name FROM contact x order by name asc nulls last, x.account.name desc",
        @"SELECT subject, TYPEOF what WHEN account Then id,BillingCity,createdBy.alias WHEN opportunity then name,nextStep ELSE id,email END FROM Task",
        @"SELECT calendar_year(createdDate), count(id) from case group by calendar_year(createdDate) order by calendar_year(createdDate) desc",
        @"SELECT calendar_year(createdDate), count(id) from case group by rollup (calendar_year(createdDate)) order by calendar_year(createdDate) desc",
        @"SELECT calendar_year(createdDate), count(id) from case group by cube( calendar_year(createdDate)) order by calendar_year(createdDate) desc",
        @"SELECT email, count(id) from contact group by email order by email nulls last",
        @"SELECT email, count(id) from contact group by email having count(id) > 1 order by email nulls last"

    ];

    
    SoqlColorizer *c = [SoqlColorizer new];
    __block NSMutableString *results = [NSMutableString stringWithCapacity:1024];
    
    for (NSString *q in queries) {
        [results appendString:q];
        [results appendString:@"\n"];
        [c enumerateTokens:q describes:descs block:^void(SoqlTokenType t, NSRange loc) {
            [results appendFormat:@"%15@ %3lu:%-3lu\t%@\n",
                [[self tokenName:t] stringByPaddingToLength:10 withString:@" " startingAtIndex:0],
                loc.location, loc.length, [q substringWithRange:loc]];
        }];
        [results appendString:@"\n"];
    }
    NSError *err = nil;
    NSString *thisFile = [NSString stringWithUTF8String:__FILE__];
    NSString *outFile = [[thisFile stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"color_test.txt"];
    [results writeToFile:outFile atomically:YES encoding:NSUTF8StringEncoding error:&err];
    XCTAssertNil(err);
    // git diff file and commit if valid.
}


@end
