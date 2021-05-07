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
#import "SoqlTokenizer.h"
#import "SoqlToken.h"

@interface SoqlTokenizerTests : XCTestCase

@end

@interface TestDescriber : NSObject<TokenizerDescriber>
@property (strong,nonatomic) NSArray<ZKDescribeSObject*>* objects;
@end

@implementation TestDescriber
-(ZKDescribeSObject*)describe:(NSString*)obj {
    for (ZKDescribeSObject *o in self.objects) {
        if ([obj caseInsensitiveCompare:o.name] == NSOrderedSame) {
            return o;
        }
    }
    return nil;
}
-(BOOL)knownSObject:(NSString*)obj {
    // simulate Case being valid, but not yet described.
    return ([obj caseInsensitiveCompare:@"Case"] == NSOrderedSame) || [self describe:obj] != nil;
}

- (NSArray<NSString *> *)allQueryableSObjects {
    return [self.objects valueForKey:@"name"];
}

- (NSImage *)iconForSObject:(NSString *)type {
    return nil;
}

@end

@implementation SoqlTokenizerTests

NSObject<TokenizerDescriber> *descs;

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    ZKDescribeField *fid = [ZKDescribeField new];
    fid.name = @"Id";
    fid.type = @"id";
    fid.aggregatable = TRUE;
    ZKDescribeField *fAccount = [ZKDescribeField new];
    fAccount.referenceTo = @[@"Account"];
    fAccount.name = @"AccountId";
    fAccount.relationshipName = @"Account";
    fAccount.namePointing = NO;
    ZKDescribeField *fName = [ZKDescribeField new];
    fName.name = @"Name";
    fName.aggregatable = TRUE;
    ZKDescribeSObject *contact = [ZKDescribeSObject new];
    contact.name = @"Contact";
    contact.fields = @[fid, fAccount,fName];
    
    ZKDescribeSObject *account = [ZKDescribeSObject new];
    account.name = @"Account";
    ZKDescribeField *fCity = [ZKDescribeField new];
    fCity.name = @"city";
    fCity.groupable = TRUE;
    ZKDescribeField *fAmount = [ZKDescribeField new];
    fAmount.name = @"amount";
    fAmount.type = @"currency";
    fAmount.aggregatable = TRUE;
    ZKDescribeField *fLastMod = [ZKDescribeField new];
    fLastMod.name = @"LastModifiedDate";
    fLastMod.type = @"datetime";
    fLastMod.aggregatable = TRUE;
    account.fields = @[fid, fLastMod, fAmount, fName, fCity];
    ZKChildRelationship *contacts = [ZKChildRelationship new];
    contacts.childSObject = @"Contact";
    contacts.relationshipName = @"Contacts";
    account.childRelationships = @[contacts];
    
    TestDescriber *d = [TestDescriber new];
    d.objects = @[account, contact];
    descs = d;
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

-(void)testFuncs {
    NSArray<NSString*>* q = @[
        @"SELECT FORMAT(Name) Amt FROM account",
        @"SELECT FORMAT(Namer) Amt FROM account",
        @"SELECT FORMAT(Namer) Amt FROM case",
        @"SELECT FORMAT(MIN(lastModifiedDate)) Amt FROM account",
        @"SELECT format(convertCurrency(Amount)) FROM account WHERE amount > USD20",
        @"SELECT format(max(Amount)) FROM account WHERE amount > USD20",
        @"SELECT max(convertCurrency(Amount)) FROM account WHERE amount > USD20",
        @"SELECT format(convertCurrency(city)) FROM account WHERE amount > USD20",
        @"SELECT name, DISTANCE(mailing__c, GEOLOCATION(1,1), 'mi') FROM account WHERE DISTANCE(mailing__c, GEOLOCATION(1,1), 'mi') > 20",
        @"select max(name) from account where CALENDARY_YEAR(createdDate) > 2018",
        // example from https://developer.salesforce.com/docs/atlas.en-us.soql_sosl.meta/soql_sosl/sforce_api_calls_soql_alias.htm
        @"SELECT count() FROM Contact c, c.Account a WHERE a.name = 'MyriadPubs'",
        // a less convoluted example of the same query
        @"SELECT count() FROM Contact WHERE account.name = 'Salesforce.com'",
        // more related convoluted examples, described in SoqlTokenizer
        @"SELECT count() FROM Contact c, c.Account a, a.CreatedBy u WHERE u.alias = 'Sfell'",
        @"SELECT count() FROM Contact c, a.CreatedBy u, c.Account a WHERE u.alias = 'Sfell'",
        @"SELECT count() FROM Contact c, c.CreatedBy u, c.Account a WHERE u.alias = 'Sfell' and a.Name > 'a'",
        @"SELECT count() FROM Contact x, x.Account.CreatedBy u, x.CreatedBy a WHERE u.alias = 'Sfell' and a.alias='Sfell'",
        @"SELECT calendar_year(lastModifiedDate) from account",
        @"SELECT calendar_year(createdDate) from account",
        @"SELECT calendar_year(name) from account",
        @"SELECT calendar_year(lastModifiedDate), count(id) from account group by calendar_year(lastModifiedDate) order by calendar_year(name) desc",
        @"SELECT calendar_year(lastModifiedDate), count(id) from account group by rollup (calendar_year(createdDate)) order by calendar_year(createdDate) desc",
        @"SELECT calendar_year(lastModifiedDate), count(id) from account group by cube( calendar_year(createdDate)) order by calendar_year(createdDate) desc",
        @"SELECT email, count(id) from contact group by email order by email nulls last",
        @"SELECT email, count(id) from contact group by email having count(id) > 1 order by email nulls last",
        @"SELECT email, bogus(id) from contact group by email",
        @"SELECT calendar_year(convertTimeZone(LastModifiedDate)) from account",
        @"SELECT calendar_year(convertCurrency(LastModifiedDate)) from account",
        @"SELECT calendar_year(convertCurrency(amount)) from account",
    ];
    [self writeSoqlTokensForQuerys:q toFile:@"funcs.txt"];
}

-(void)testSelectExprs {
    NSArray<NSString*>* queries = @[
        @"select id,(select name from contacts),name from account where name in ('bob','eve','alice')",
        @"select (select c.name from contacts c),name from account a where a.name>='bob'",
        @"SELECT subject, TYPEOF what WHEN account Then id,BillingCity,createdBy.alias WHEN opportunity then name,nextStep ELSE id,email END FROM Task",
        @"SELECT fields(STANDARD) FROM KnowledgeArticleVersion WITH DATA CATEGORY Geography__c BELOW usa__c AND Product__c AT mobile_phones__c",
        @"SELECT fields(STANDARD) FROM KnowledgeArticleVersion WITH DATA CATEGORY Geography__c NEAR usa__c AND Product__c AT mobile_phones__c",
        @"SELECT fields(what) FROM KnowledgeArticleVersion",
        @"SELECT account from contact"
    ];
    [self writeSoqlTokensForQuerys:queries toFile:@"select_exprs.txt"];
}

-(void)testScope {
    NSArray<NSString*>* queries = @[
        @"select id,(select name from contacts),name from account using scope team",
        @"select id,(select name from contacts),name from account using team",
        @"select id,(select name from contacts),name from account scope team",
        @"select id,(select name from contacts),name from account using scope team team2",
    ];
    [self writeSoqlTokensForQuerys:queries toFile:@"using_scope.txt"];
}

-(void)testOrderBy {
    NSArray<NSString*>* queries = @[
        @"SELECT name FROM contact order by name",
        @"SELECT name FROM contact order by name asc",
        @"SELECT name FROM contact order by name asc nulls last",
        @"SELECT name FROM contact order by name asc nulls last, account.name desc",
        @"SELECT name FROM contact x order by name asc nulls last, x.account.name desc",
        @"SELECT name FROM contact order by name asc limit 1",
        @"SELECT name FROM contact orderby name",
        @"SELECT name FROM contact order name",
        @"SELECT name FROM contact by name",
        @"SELECT name FROM contact order by",
    ];
    [self writeSoqlTokensForQuerys:queries toFile:@"order_by.txt"];
}

-(void)testForDebugging {
    [self writeSoqlTokensForQuerys:@[@"select count() from account"] toFile:@"debug.txt" withDebug:YES];
}

- (void)testWhere {
    NSArray<NSString*>* queries = @[
        @"select name from account where name='bob'",
        @"select name from account where name='bob' or name='eve' or (name='alice' and city='SF')",
        @"select name from account where name='bob' or name='eve' or not name='alice'",
        @"select name from account where name in('bob','eve','alice')",
        @"select name from account where name not in('bob','eve','alice')",
        @"select name from account where not name > 't' and name not in('bob','eve','alice')",
        @"select namer from account where name='bob'",
        @"select name from account where namer='bob'",
        @"select name from case where LastModifiedDate >= YESTERDAY",
        @"select name from case c",
        @"select name from account where id in ('001002003004005006')",
        @"select name from account where id in (select accountId from contact)",
        @"SELECT name FROM account WHERE id NOT IN (SELECT accountId FROM contact)",
        @"select account.city from contact where name LIKE 'b%'",
        @"select account.city from contact where name LIKE 'b%' OR name='eve'",
        @"select c.account.city from contact c where name LIKE 'b%'",
        @"select account.name from account where name > 'bob'",
        @"select a.name from account a where name > 'bob'",
        @"SELECT x.name FROM Contact x, x.Account.CreatedBy u, x.CreatedBy a WHERE u.alias = 'Sfell' and (a.alias='Sfell' or x.MailingCity IN('SF','LA'))order by x.name desc nulls first",
        @"SELECT account.name.name FROM account",
        @"select a.name from account a where name > 'bob' LIMIt 5",
        @"select a.name from account a where name > 'bob' LIMIt 5 OFFSET 5",
        @"select a.name from account a where name > 'bob' LIMIt 5 OFFSET 5 FOR view",
        @"select a.name from account a where name > 'bob' LIMIt 5 OFFSET 5 update viewstat",
        @"SELECT Id, Name FROM Account WHERE Amount > USD5000",
        @"SELECT Id, Name FROM Account WHERE msp__c Includes('abc;def','q')",
        @"SELECT Id, Name FROM Account WHERE msp__c excludes ( 'abc;def' , 'q' ) ",
        @"SELECT Id, Name FROM case WHERE Amount > USD5000",
        @"SELECT Id, Name FROM case WHERE msp__c Includes('abc;def','q')",
        @"SELECT Id, Name FROM case WHERE msp__c excludes ( 'abc;def' , 'q' ) ",
        @"select name from account where name bob 'bob'",
        @"select name from account where name ^ 'bob'",
    ];
    [self writeSoqlTokensForQuerys:queries toFile:@"where.txt"];
}

-(void)testLiterals {
    NSArray<NSString*>* queries = @[
        @"select id from account where name='bob'",
        @"select id from account where name='bob",
        @"select id from account where name='bob\\",
        @"select id from account where name in ('bob','alice')",
        @"select id from account where name in ('bob','alice'",
        @"select id from account where lastModifiedDate >= 2020-01-01",
        @"select id from account where lastModifiedDate >= 2020-01-01T13:14:15Z",
        @"select id from account where lastModifiedDate >= 2020-01-01T13:14:15-08:00",
        @"select id from account where name=null",
        @"select id from account where name=true",
        @"select id from account where name=false",
        @"select id from account where name> 10",
        @"select id from account where name> 10.123",
        @"select id from account where name> USD200",
        @"select id from account where lastModifiedDate < YESTERDAY",
    ];
    [self writeSoqlTokensForQuerys:queries toFile:@"literals.txt"];
}

- (void)testGroupBy {
    NSArray<NSString*>* queries = @[
        @"select amount, count(id) from account group by amount", // amount is not groupable in describe
        @"select city, count(id) from account group by city",
        @"select city, count(id) from account group by city order by count(id) asc",
        // city is not aggregatable, so there should be an error for the count_distinct(city) expr
        @"select count_distinct(city) from account group by calendar_year(lastModifiedDate)",
        @"select account.city, count(id) from contact group by account.city",
        @"select city, count(id) from account group by rollup (city)",
        @"select city, count(id) from account group by rollup (city,state)",
        @"select city, count(id) from account group by cube(city)",
        // based on example from group by cube docs
        @"SELECT city, GROUPING(city) grpCity FROM Account GROUP BY CUBE(city) ORDER BY GROUPING(City)",
        @"select city, count(id) from account group by city having count(id) < 10",
        @"select city, count(id) from account group by city having count(id) < 10 or count(id) > 100",
    ];
    [self writeSoqlTokensForQuerys:queries toFile:@"group_by.txt"];
}

- (void)testWith {
    NSArray<NSString*>* queries = @[
        @"select name from account WITH DATA CATEGORY Geography__c AT asia__c",
        @"select name from account WITH DATA CATEGORY Geography__c AT asia__c AND product__c BELOW electronics__c",
        @"select name from account WITH DATA CATEGORY Geography__c AT asia__c OR product__c BELOW electronics__c",
        @"select name from account WITH DATA CATEGORY Geography__c NEAR asia__c",
    ];
    [self writeSoqlTokensForQuerys:queries toFile:@"with.txt"];
}

-(void)testLimitOffset {
    NSArray<NSString*>* queries = @[
        @"select name from account",
        @"select name from account limit 1",
        @"select name from account limit 1 offset 123456",
        @"select name from account limit 1 offset 123456 for view",
        @"select name from account limit 1 offset 123456 for reference",
        @"select name from account limit 1 offset 123456 for view update tracking",
        @"select name from account limit 1 offset 123456 ",
        @"select name from account limit 1 offset 123456 update viewstat",
        @"select name from account limit 1 for view",
    ];
    [self writeSoqlTokensForQuerys:queries toFile:@"limit_offset.txt"];
}

-(void)writeSoqlTokensForQuerys:(NSArray<NSString*>*)queries toFile:(NSString*)fn {
    [self writeSoqlTokensForQuerys:queries toFile:fn withDebug:NO];
}

-(void)writeSoqlTokensForQuerys:(NSArray<NSString*>*)queries toFile:(NSString*)fn withDebug:(BOOL)appendDebug {
    SoqlTokenizer *c = [SoqlTokenizer new];
    NSString *debugFile = [NSString stringWithFormat:@"%@/soql.debug", NSTemporaryDirectory()];
    if (appendDebug) {
        [[NSFileManager defaultManager] removeItemAtPath:debugFile error:nil];
        [c setDebugOutputTo:debugFile];
    }
    c.describer = descs;
    NSMutableString *results = [NSMutableString stringWithCapacity:1024];
    for (NSString *q in queries) {
        [results appendString:q];
        [results appendString:@"\n"];
        Tokens *t = [c parseAndResolve:q];
        [results appendString:t.description];
        [results appendString:@"\n"];
    }
    if (appendDebug) {
        NSString *dbg = [NSString stringWithContentsOfFile:debugFile encoding:NSUTF8StringEncoding error:nil];
        [results appendString:@"Parser debug\n"];
        [results appendString:dbg];
        [results appendString:@"\n"];
    }
    NSError *err = nil;
    NSString *thisFile = [NSString stringWithUTF8String:__FILE__];
    NSString *outFile = [[thisFile stringByDeletingLastPathComponent] stringByAppendingPathComponent:fn];
    [results writeToFile:outFile atomically:YES encoding:NSUTF8StringEncoding error:&err];
    XCTAssertNil(err);
    // git diff file and commit if valid.
}

@end
