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


#import "zkXmlDeserializer.h"

/*
<element name="autoNumber"         type="xsd:boolean"/>
<element name="byteLength"         type="xsd:int"/>
<element name="calculated"         type="xsd:boolean"/>
<element name="calculatedFormula"  type="xsd:string" minOccurs="0"/>
<element name="caseSensitive"      type="xsd:boolean"/>
<element name="controllerName"     type="xsd:string" minOccurs="0"/>
<element name="createable"         type="xsd:boolean"/>
<element name="custom"             type="xsd:boolean"/>
<element name="defaultValueFormula" type="xsd:string" minOccurs="0"/>
<element name="defaultedOnCreate"  type="xsd:boolean"/>
<element name="dependentPicklist"  type="xsd:boolean" minOccurs="0"/>
<element name="digits"             type="xsd:int"/>
<element name="externalId"         type="xsd:boolean" minOccurs="0"/>
<element name="filterable"         type="xsd:boolean"/>
<element name="htmlFormatted"      type="xsd:boolean" minOccurs="0"/>
<element name="idLookup"           type="xsd:boolean"/>
<element name="label"              type="xsd:string"/>
<element name="length"             type="xsd:int"/>
<element name="name"               type="xsd:string"/>
<element name="nameField"          type="xsd:boolean"/>
<element name="namePointing"       type="xsd:boolean" minOccurs="0"/>
<element name="nillable"           type="xsd:boolean"/>
<element name="picklistValues"     type="tns:PicklistEntry" nillable="true" minOccurs="0" maxOccurs="unbounded"/>
<element name="precision"          type="xsd:int"/>
<element name="referenceTo"        type="xsd:string" nillable="true" minOccurs="0" maxOccurs="unbounded"/>
<element name="relationshipName"   type="xsd:string" minOccurs="0"/>
<element name="relationshipOrder"  type="xsd:int" minOccurs="0"/>
<element name="restrictedPicklist" type="xsd:boolean"/>
<element name="scale"              type="xsd:int"/>
<element name="soapType"           type="tns:soapType"/>
<element name="sortable"           type="xsd:boolean" minOccurs="0"/>
<element name="type"               type="tns:fieldType"/>
<element name="unique"             type="xsd:boolean"/>
<element name="updateable"         type="xsd:boolean"/>
<element name="writeRequiresMasterRead" type="xsd:boolean" minOccurs="0"/>

*/

@class ZKDescribeSObject;

@interface ZKDescribeField : ZKXmlDeserializer <NSCopying> {
	NSArray				*picklistValues;
	ZKDescribeSObject	*sobject;
}
- (void)setSobject:(ZKDescribeSObject *)s;
- (ZKDescribeSObject *)sobject;

// Api v7.0
- (BOOL)autoNumber;
- (int)byteLength;
- (BOOL)calculated;
- (NSString *)controllerName;
- (BOOL)createable;
- (BOOL)custom;
- (BOOL)defaultOnCreate;
- (BOOL)dependentPicklist;
- (int)digits;
- (BOOL)externalId;
- (BOOL)filterable;
- (BOOL)htmlFormatted;
- (NSString *)label;
- (int)length;
- (NSString *)name;
- (BOOL)nameField;
- (BOOL)nillable;
- (NSArray *)picklistValues;
- (int)precision;
- (NSArray *)referenceTo;
- (NSString *)relationshipName;
- (BOOL)restrictedPicklist;
- (int)scale;
- (NSString *)soapType;
- (NSString *)type;
- (BOOL)updateable;
// Api v8.0
- (NSString *)calculatedFormula;
- (BOOL)caseSensitive;
- (NSString *)defaultValueFormula;
- (BOOL)namePointing;
- (BOOL)sortable;
- (BOOL)unique;
// Api v11.1
- (BOOL)idLookup;
// Api v13.0
- (int)relationshipOrder;			// for CJO's, is this the first or 2nd FK to the parent ?
- (BOOL)writeRequiresMasterRead;	// writing to this requires at least read access to the parent object (e.g. on CJO's)
// Api v14.0
- (NSString *)inlineHelpText;
// Api v18.0
- (BOOL)groupable;

@end
