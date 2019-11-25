// Copyright (c) 2012 Simon Fell
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

#import "ZKDescribe_Reporting.h"
#import <ZKSforce/ZKPicklistEntry.h>
#import <ZKSforce/ZKChildRelationship.h>


@implementation ZKDescribeField (Reporting)
- (NSString *)descriptiveType {
	NSString *type = [self type];
	if ([type isEqualToString:@"string"])
		return [NSString stringWithFormat:@"text(%ld)", (long)[self length]];
	if ([type isEqualToString:@"picklist"])
		return @"picklist";
	if ([type isEqualToString:@"multipicklist"])
		return @"multi select picklist";
	if ([type isEqualToString:@"combobox"])
		return @"combo box";
	if ([type isEqualToString:@"reference"])
		return @"foreign key";
	if ([type isEqualToString:@"base64"])
		return @"blob";
	if ([type isEqualToString:@"textarea"])
		return [NSString stringWithFormat:@"textarea(%ld)", (long)[self length]];
	if ([type isEqualToString:@"currency"])
		return [NSString stringWithFormat:@"currency(%ld,%ld)", (long)([self precision] - [self scale]), (long)[self scale]];
	if ([type isEqualToString:@"double"])
		return [NSString stringWithFormat:@"double(%ld,%ld)", (long)([self precision] - [self scale]), (long)[self scale]];
	if ([type isEqualToString:@"int"])
		return [NSString stringWithFormat:@"int(%ld)", (long)[self digits]];
	return type;
}

- (NSString *)picklistProperties {
	NSMutableString *pp = [NSMutableString string];
    for (ZKPicklistEntry *ple in [self picklistValues]) {
        if (![ple active]) continue;
		if ([[ple label] isEqualToString:[ple value]])
			[pp appendFormat:@"%@<br>", [ple value]];
		else
			[pp appendFormat:@"%@ (%@)<br>", [ple label], [ple value]];
	}
	return pp;
}

- (NSString *)referenceProperties {
	NSMutableString *rp = [NSMutableString string];
    for (NSString *type in [self referenceTo]) {
		[rp appendFormat:@"%@<br>", type];
    }
	return rp;
}

- (NSString *)properties {
	NSString *type = [self type];
	if ([type isEqualToString:@"picklist"] || [type isEqualToString:@"multipicklist"])
		return [self picklistProperties];
	if ([type isEqualToString:@"reference"])
		return [self referenceProperties];
	return @"";
}
@end

@implementation ZKDescribeSObject (Reporting)
- (NSSet *)namesOfAllReferencedObjects {
	NSMutableSet *names = [NSMutableSet setWithCapacity:20];
    for (ZKChildRelationship *cr in [self childRelationships]) {
		[names addObject:[cr childSObject]];
    }
    for (ZKDescribeField *f in [self fields]) {
		if (![[f type] isEqualToString:@"reference"]) continue;
		[names addObjectsFromArray:[f referenceTo]];
	}
	return names;
}
@end

@implementation DescribeListDataSource (Reporting)

- (BOOL)hasAllDescribesRelatedTo:(NSString *)sobjectType {
    if (![self hasDescribe:sobjectType]) {
        return NO;
    }
	ZKDescribeSObject *desc = [self cachedDescribe:sobjectType];
    for (NSString *t in [desc namesOfAllReferencedObjects]) {
        if (![self hasDescribe:t]) {
            return NO;
        }
	}
	return YES;
}

@end
