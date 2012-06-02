//
//  zkExecuteAnonResult.h
//  apexCoder
//
//  Created by Simon Fell on 6/9/07.
//  Copyright 2007 Simon Fell. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "zkXmlDeserializer.h"

/*
     <xsd:element name="column" type="xsd:int"/> 
     <xsd:element name="compileProblem" type="xsd:string" nillable="true"/> 
     <xsd:element name="compiled" type="xsd:boolean"/> 
     <xsd:element name="exceptionMessage" type="xsd:string" nillable="true"/> 
     <xsd:element name="exceptionStackTrace" type="xsd:string" nillable="true"/> 
     <xsd:element name="line" type="xsd:int"/> 
     <xsd:element name="success" type="xsd:boolean"/> 
*/

@interface ZKExecuteAnonymousResult : ZKXmlDeserializer {
}

- (int)column;
- (int)line;
- (BOOL)compiled;
- (NSString *)compileProblem;
- (NSString *)exceptionMessage;
- (NSString *)exceptionStackTrace;
- (BOOL)success;

@end
