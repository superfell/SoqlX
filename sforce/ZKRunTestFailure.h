//
//  ZKRunTestFailure.h
//  apexCoder
//
//  Created by Simon Fell on 6/10/07.
//  Copyright 2007 Simon Fell. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "zkXmlDeserializer.h"

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
