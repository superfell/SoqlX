//
//  ZKCodeLocation.h
//  apexCoder
//
//  Created by Simon Fell on 6/10/07.
//  Copyright 2007 Simon Fell. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "zkXmlDeserializer.h"

// <xsd:element name="column" type="xsd:int"/>
// <xsd:element name="line" type="xsd:int"/>
// <xsd:element name="numExecutions" type="xsd:int"/>
// <xsd:element name="time" type="xsd:double"/>

@interface ZKCodeLocation : ZKXmlDeserializer {
}

- (int)column;
- (int)line;
- (int)numExecutions;
- (double)time;

@end
