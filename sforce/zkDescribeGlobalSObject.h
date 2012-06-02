// Copyright (c) 2009-2010 Simon Fell
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
            <complexType name="DescribeGlobalSObjectResult">
                <sequence>
                    <element name="activateable"        type="xsd:boolean"/>
                    <element name="createable"          type="xsd:boolean"/>
                    <element name="custom"              type="xsd:boolean"/>
                    <element name="customSetting"       type="xsd:boolean"/>
                    <element name="deletable"           type="xsd:boolean"/>
                    <element name="deprecatedAndHidden" type="xsd:boolean"/>
					<element name="feedEnabled"         type="xsd:boolean"/>
                    <element name="keyPrefix"           type="xsd:string" nillable="true"/>

                    <element name="label"               type="xsd:string"/>
                    <element name="labelPlural"         type="xsd:string"/>
                    <element name="layoutable"          type="xsd:boolean"/>
					<element name="mergeable"           type="xsd:boolean"/>
                    <element name="name"                type="xsd:string"/>
                    <element name="queryable"           type="xsd:boolean"/>
                    <element name="replicateable"       type="xsd:boolean"/>
                    <element name="retrieveable"        type="xsd:boolean"/>
					<element name="searchable"          type="xsd:boolean"/>

                    <element name="triggerable"         type="xsd:boolean"/>
                    <element name="undeletable"         type="xsd:boolean"/>
                    <element name="updateable"          type="xsd:boolean"/>
                </sequence>
            </complexType>
*/
@interface ZKDescribeGlobalSObject : ZKXmlDeserializer {
}

-(BOOL)activateable;
-(BOOL)createable;
-(BOOL)custom;
-(BOOL)customSetting;
-(BOOL)deletable;
-(BOOL)deprecatedAndHidden;
-(BOOL)feedEnabled;
-(BOOL)layoutable;
-(BOOL)mergeable;
-(BOOL)queryable;
-(BOOL)replicateable;
-(BOOL)retrieveable;
-(BOOL)searchable;
-(BOOL)triggerable;
-(BOOL)undeleteable;
-(BOOL)updateable;

-(NSString *)keyPrefix;
-(NSString *)label;
-(NSString *)labelPlural;
-(NSString *)name;

@end
