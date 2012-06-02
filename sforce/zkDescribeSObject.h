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
#import "zkDescribeField.h"
#import "zkDescribeGlobalSObject.h"

/*
<element name="activateable"   		type="xsd:boolean"/>
<element name="childRelationships" 	type="tns:ChildRelationship" minOccurs="0" maxOccurs="unbounded"/>
<element name="createable"     		type="xsd:boolean"/>
<element name="custom"         		type="xsd:boolean"/>
<element name="deletable"      		type="xsd:boolean"/>
<element name="fields"         		type="tns:Field" nillable="true" minOccurs="0" maxOccurs="unbounded"/>
<element name="keyPrefix"      		type="xsd:string" nillable="true"/>
<element name="label"          		type="xsd:string"/>
<element name="labelPlural"    		type="xsd:string"/>
<element name="layoutable"     		type="xsd:boolean"/>
<element name="mergeable"           type="xsd:boolean"/>
<element name="name"           		type="xsd:string"/>
<element name="queryable"      		type="xsd:boolean"/>
<element name="recordTypeInfos"     type="tns:RecordTypeInfo" minOccurs="0" maxOccurs="unbounded"/>
<element name="replicateable"  		type="xsd:boolean"/>
<element name="retrieveable"   		type="xsd:boolean"/>
<element name="searchable"     		type="xsd:boolean"/>
<element name="triggerable"         type="xsd:boolean" minOccurs="0"/>
<element name="undeletable"    		type="xsd:boolean"/>
<element name="updateable"     		type="xsd:boolean"/>
<element name="urlDetail"      		type="xsd:string" nillable="true"/>
<element name="urlEdit"        		type="xsd:string" nillable="true"/>
<element name="urlNew"         		type="xsd:string" nillable="true"/>
 */
 
@interface ZKDescribeSObject : ZKDescribeGlobalSObject {
	NSArray			*fields;
	NSDictionary	*fieldsByName;
	NSArray			*childRelationships;
	NSArray 		*recordTypeInfos;
}

-(NSString *)urlDetail;
-(NSString *)urlEdit;
-(NSString *)urlNew;
-(NSArray *)fields;
-(ZKDescribeField *)fieldWithName:(NSString *)name;
-(NSArray *)childRelationships;
-(NSArray *)recordTypeInfos;
@end
