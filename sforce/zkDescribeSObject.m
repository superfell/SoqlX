// Copyright (c) 2006-2007 Simon Fell
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


#import "zkDescribeSObject.h"
#import "zkDescribeField.h"
#import "zkChildRelationship.h"
#import "zkRecordTypeInfo.h"
#import "zkParser.h"

@implementation ZKDescribeSObject

-(void)dealloc {
	[fields release];
	[fieldsByName release];
	[childRelationships release];
	[recordTypeInfos release];
	[super dealloc];
}


-(NSString *)urlDetail {
	return [self string:@"urlDetail"];
}
-(NSString *)urlEdit {
	return [self string:@"urlEdit"];
}
-(NSString *)urlNew {
	return [self string:@"urlNew"];
}

-(NSArray *)fields {
	if (fields == nil) {
		NSArray * fn = [node childElements:@"fields"];
		NSMutableDictionary *byName = [NSMutableDictionary dictionary];
		NSMutableArray * fs = [NSMutableArray arrayWithCapacity:[fn count]];
		for (zkElement *fieldNode in fn) {
			ZKDescribeField * df = [[ZKDescribeField alloc] initWithXmlElement:fieldNode];
			[df setSobject:self];
			[fs addObject:df];
			[byName setObject:df forKey:[[df name] lowercaseString]];
			[df release];
		}
		fields = [fs retain];
		fieldsByName = [byName retain];
	}
	return fields;
}

-(ZKDescribeField *)fieldWithName:(NSString *)name {
	if (fieldsByName == nil) 
		[self fields];
	return [fieldsByName objectForKey:[name lowercaseString]];
}

-(NSArray *)childRelationships {
	if (childRelationships == nil) {
		NSArray *crn = [node childElements:@"childRelationships"];
		NSMutableArray *crs = [NSMutableArray arrayWithCapacity:[crn count]];
		for (zkElement *crNode in crn) {
			ZKChildRelationship * cr = [[ZKChildRelationship alloc] initWithXmlElement:crNode];
			[crs addObject:cr];
			[cr release];
		}
		childRelationships = [crs retain];
	}
	return childRelationships;
}

- (NSString *)description {
	return [NSString stringWithFormat:@"SObject %@ (%@)", [self name], [self label]];
}

-(NSArray *)recordTypeInfos {
	if (recordTypeInfos == nil) {
		NSArray *rti = [node childElements:@"recordTypeInfos"];
		NSMutableArray *res = [NSMutableArray arrayWithCapacity:[rti count]];
		for (zkElement *rnode in rti) {
			ZKRecordTypeInfo *r = [[ZKRecordTypeInfo alloc] initWithXmlElement:rnode];
			[res addObject:r];
			[r release];
		}
		recordTypeInfos = [res retain];
	}
	return recordTypeInfos;
}

@end
