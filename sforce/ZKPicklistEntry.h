// Copyright (c) 2007 Simon Fell
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

//<complexType name="PicklistEntry">
//    <sequence>
//        <element name="active"       type="xsd:boolean"/>
//        <element name="defaultValue" type="xsd:boolean"/>
//        <element name="label"        type="xsd:string" nillable="true"/>
//        <element name="validFor"     type="xsd:base64Binary" minOccurs="0"/>
//        <element name="value"        type="xsd:string"/>
//    </sequence>
//</complexType>

@interface ZKPicklistEntry : ZKXmlDeserializer {
}
- (BOOL)active;
- (BOOL)defaultValue;
- (NSString *)label;
- (NSString *)validFor;
- (NSString *)value;
@end
