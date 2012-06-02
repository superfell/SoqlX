//
//  ZKCodeCoverageResult.h
//  apexCoder
//
//  Created by Simon Fell on 6/10/07.
//  Copyright 2007 Simon Fell. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "zkXmlDeserializer.h"

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
