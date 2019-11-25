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

// <xsd:element name="message" type="xsd:string"/>
// <xsd:element name="methodName" type="xsd:string"/>
// <xsd:element name="namespace" type="xsd:string"/>
// <xsd:element name="packageName" type="xsd:string"/>
// <xsd:element name="stackTrace" type="xsd:string"/>

@interface ZKRunTestFailure : ZKXmlDeserializer {
}

- (NSString *)message;
- (NSString *)namespace;
- (NSString *)packageName;
- (NSString *)methodName;
- (NSString *)stackTrace;

@end
