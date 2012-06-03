// Copyright (c) 2006 Simon Fell
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


#import "zkDescribeField.h"
#import "zkPicklistEntry.h"
#import "zkParser.h"

@implementation ZKDescribeField

- (void)dealloc {
	[picklistValues release];
	[super dealloc];
}

- (id)copyWithZone:(NSZone *)zone {
	zkElement *n = [[node copyWithZone:zone] autorelease];
	ZKDescribeField *rhs = [[ZKDescribeField alloc] initWithXmlElement:n];
	[rhs setSobject:sobject];
	return rhs;
}

- (zkElement *)node {
	return node;
}

- (BOOL)isEqual:(id)anObject {
	if (![anObject isKindOfClass:[ZKDescribeField class]]) return NO;
	return [node isEqual:[anObject node]];
}

- (void)setSobject:(ZKDescribeSObject *)s {
	// note we explicitly don't retain this to stop a retain cycle between us and the parent sobject.
	// as it has a reatined reference on us, it can't go away before we do.
	sobject = s;
}

- (ZKDescribeSObject *)sobject {
	return sobject;
}

- (unsigned)hash {
	return [node hash];
}
- (BOOL)autoNumber {
	return [self boolean:@"autoNumber"];
}
- (int)byteLength {
	return [self integer:@"byteLength"];
}
- (BOOL)calculated {
	return [self boolean:@"calculated"];
}
- (NSString *)controllerName {
	return [self string:@"controllerName"];
}
- (BOOL)createable {
	return [self boolean:@"createable"];
}
- (BOOL)custom {
	return [self boolean:@"custom"];
}
- (BOOL)defaultOnCreate {
	return [self boolean:@"defaultOnCreate"];
}
- (BOOL)dependentPicklist {
	return [self boolean:@"dependentPicklist"];
}
- (int)digits {
	return [self integer:@"digits"];
}
- (BOOL)externalId {
	return [self boolean:@"externalId"];
}
- (BOOL)filterable {
	return [self boolean:@"filterable"];
}
- (BOOL)htmlFormatted {
	return [self boolean:@"htmlFormatted"];
}
- (NSString *)label {
	return [self string:@"label"];
}
- (int)length {
	return [self integer:@"length"];
}
- (NSString *)name {
	return [self string:@"name"];
}
- (BOOL)nameField {
	return [self boolean:@"nameField"];
}
- (BOOL)nillable {
	return [self boolean:@"nillable"];
}
- (NSArray *)picklistValues {
	if (picklistValues == nil) 
		picklistValues = [[self complexTypeArrayFromElements:@"picklistValues" cls:[ZKPicklistEntry class]] retain];
	return picklistValues;
}
- (int)precision {
	return [self integer:@"precision"];
}
- (NSArray *)referenceTo {
	return [self strings:@"referenceTo"];
}
- (NSString *)relationshipName {
	return [self string:@"relationshipName"];
}
- (BOOL)restrictedPicklist {
	return [self boolean:@"restrictedPicklist"];
}
- (int)scale {
	return [self integer:@"scale"];
}
- (NSString *)soapType {
	return [self string:@"soapType"];
}
- (NSString *)type {
	return [self string:@"type"];
}
- (BOOL)updateable {
	return [self boolean:@"updateable"];
}
- (NSString *)description {
	return [NSString stringWithFormat:@"Field %@ (%@)", [self name], [self label]];
}
- (NSString *)calculatedFormula {
	return [self string:@"calculatedFormula"];
}
- (BOOL)caseSensitive {
	return [self boolean:@"caseSensitive"];
}
- (NSString *)defaultValueFormula {
	return [self string:@"defaultValueFormula"];
}
- (BOOL)namePointing {
	return [self boolean:@"namePointing"];
}
- (BOOL)sortable {
	return [self boolean:@"sortable"];
}
- (BOOL)unique {
	return [self boolean:@"unique"];
}
- (BOOL)idLookup {
	return [self boolean:@"idLookup"];
}
- (int)relationshipOrder {
	return [self integer:@"relationshipOrder"];
}
- (BOOL)writeRequiresMasterRead {
	return [self boolean:@"writeRequiresMasterRead"];
}
- (NSString *)inlineHelpText {
	return [self string:@"inlineHelpText"];
}
- (BOOL)groupable {
	return [self boolean:@"groupable"];
}
- (BOOL)cascadeDelete {
    return [self boolean:@"cascadeDelete"];
}
- (BOOL)displayLocationInDecimal {
    return [self boolean:@"displayLocationInDecimal"];
}

@end
