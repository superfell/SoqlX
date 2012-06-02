//
//  zkApexClient.h
//  apexCoder
//
//  Created by Simon Fell on 5/29/07.
//  Copyright 2007 Simon Fell. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "zkSforceClient.h"

@class ZKExecuteAnonymousResult;
@class ZKRunTestResult;


/*
   <xsd:simpleType name="LogCategory">
    <xsd:restriction base="xsd:string">
     <xsd:enumeration value="Db"/>
     <xsd:enumeration value="Workflow"/>
     <xsd:enumeration value="Validation"/>
     <xsd:enumeration value="Callout"/>
     <xsd:enumeration value="Apex_code"/>
     <xsd:enumeration value="Apex_profiling"/>
     <xsd:enumeration value="All"/>
    </xsd:restriction>
   </xsd:simpleType>
   <xsd:simpleType name="LogCategoryLevel">
    <xsd:restriction base="xsd:string">
     <xsd:enumeration value="Internal"/>
     <xsd:enumeration value="Finest"/>
     <xsd:enumeration value="Finer"/>
     <xsd:enumeration value="Fine"/>
     <xsd:enumeration value="Debug"/>
     <xsd:enumeration value="Info"/>
     <xsd:enumeration value="Warn"/>
     <xsd:enumeration value="Error"/>
    </xsd:restriction>
   </xsd:simpleType>
   <xsd:complexType name="LogInfo">
    <xsd:sequence>
     <xsd:element name="category" type="tns:LogCategory"/>
     <xsd:element name="level" type="tns:LogCategoryLevel"/>
    </xsd:sequence>
   </xsd:complexType>
   */

typedef enum ZKLogCategory {
	Category_Db,
	Category_Workflow,
	Category_Validation,
	Category_Callout,
	Category_Apex_code,
	Category_Apex_profiling,
	Category_All
} ZKLogCategory;

#define ZKLogCategory_Count 7

typedef enum ZKLogCategoryLevel {
	Level_None,
	Level_Error,
	Level_Warn,
	Level_Info,
	Level_Debug,
	Level_Fine,
	Level_Finer,
	Level_Finest,
	Level_Internal,
} ZKLogCategoryLevel;

@interface ZKApexClient : ZKBaseClient {
	ZKSforceClient		*sforce;	
	NSString			*lastDebugLog;
	BOOL				debugLog;
	ZKLogCategoryLevel	loggingLevels[ZKLogCategory_Count];
}

+ (id) fromClient:(ZKSforceClient *)sf;
- (id) initFromClient:(ZKSforceClient *)sf;

- (NSArray *)compilePackages:(NSArray *)src;
- (NSArray *)compileTriggers:(NSArray *)src;
- (ZKExecuteAnonymousResult *)executeAnonymous:(NSString *)src;
- (ZKRunTestResult *)runTests:(BOOL)allTests namespace:(NSString *)ns packages:(NSArray *)pkgs;

@property (assign) BOOL debugLog;
-(ZKLogCategoryLevel)debugLevelForCategory:(ZKLogCategory)c;
-(void)setDebugLevel:(ZKLogCategoryLevel)lvl forCategory:(ZKLogCategory)c;
-(NSString *)lastDebugLog;

+(NSArray *)logLevelNames;
@end
