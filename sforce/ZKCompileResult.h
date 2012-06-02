//
//  ZKCompilePackageResult.h
//  apexCoder
//
//  Created by Simon Fell on 6/8/07.
//  Copyright 2007 Simon Fell. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "zkXmlDeserializer.h"

// <xsd:complexType name="CompilePackageResult">
// <xsd:sequence>
//     <xsd:element name="bodyCrc" minOccurs="0" type="xsd:int"/>
//     <xsd:element name="column" type="xsd:int"/>
//     <xsd:element name="id" type="tns:ID" nillable="true"/>
//     <xsd:element name="line" type="xsd:int"/>
//     <xsd:element name="problem" type="xsd:string"/>
//     <xsd:element name="success" type="xsd:boolean"/>
//  </xsd:sequence>
//  </xsd:complexType>

@interface ZKCompileResult : ZKXmlDeserializer {
}

- (BOOL)success;
- (NSString *)id;
- (NSString *)problem;
- (int)bodyCrc;
- (int)column;
- (int)line;

@end
