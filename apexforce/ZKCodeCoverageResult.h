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

#import <Cocoa/Cocoa.h>
#import <ZKSforce/ZKXmlDeserializer.h>

// <xsd:element name="dmlInfo" minOccurs="0" maxOccurs="unbounded" type="tns:CodeLocation"/>
// <xsd:element name="locationsNotCovered" minOccurs="0" maxOccurs="unbounded" type="tns:CodeLocation"/>
// <xsd:element name="methodInfo" minOccurs="0" maxOccurs="unbounded" type="tns:CodeLocation"/>
// <xsd:element name="name" type="xsd:string"/>
// <xsd:element name="namespace" type="xsd:string"/>
// <xsd:element name="numLocations" type="xsd:int"/>
// <xsd:element name="numLocationsNotCovered" type="xsd:int"/>
// <xsd:element name="soqlInfo" minOccurs="0" maxOccurs="unbounded" type="tns:CodeLocation"/>
// <xsd:element name="type" type="xsd:string"/>

@interface ZKCodeCoverageResult : ZKXmlDeserializer {
}

- (NSArray *)dmlInfo;
- (NSArray *)locationsNotCovered;
- (NSArray *)methodInfo;
- (NSString *)name;
- (NSString *)namespace;
- (int)numLocations;
- (int)numLocationsNotCovered;
- (NSArray *)soqlInfo;
- (NSString *)type;

@end
