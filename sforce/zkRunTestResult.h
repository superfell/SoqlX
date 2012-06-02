//
//  zkRunTestResult.h
//  apexCoder
//
//  Created by Simon Fell on 6/10/07.
//  Copyright 2007 Simon Fell. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "zkXmlDeserializer.h"

// <xsd:element name="codeCoverage" minOccurs="0" maxOccurs="unbounded" type="tns:CodeCoverageResult"/>
// <xsd:element name="failures" minOccurs="0" maxOccurs="unbounded" type="tns:RunTestFailure"/>
// <xsd:element name="numFailures" type="xsd:int"/>
// <xsd:element name="numTestsRun" type="xsd:int"/>

@interface ZKRunTestResult : ZKXmlDeserializer {
}

- (NSArray *)codeCoverage;
- (NSArray *)failures;
- (int)numFailures;
- (int)numTestsRun;

@end
