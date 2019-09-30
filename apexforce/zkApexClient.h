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
	ZKLogCategoryLevel	loggingLevels[ZKLogCategory_Count];
}

+ (id) fromClient:(ZKSforceClient *)sf;
- (id) initFromClient:(ZKSforceClient *)sf;

-(void)compilePackages:(NSArray *)src withFailBlock:(ZKFailWithErrorBlock)failBock completeBlock:(ZKCompleteArrayBlock)completeBlock;
-(void)compileTriggers:(NSArray *)src withFailBlock:(ZKFailWithErrorBlock)failBock completeBlock:(ZKCompleteArrayBlock)completeBlock;

-(void)executeAnonymous:(NSString *)src withFailBlock:(ZKFailWithErrorBlock)failBlock
                                        completeBlock:(void(^)(ZKExecuteAnonymousResult *r))completeBlock;

-(void)runTests:(BOOL)allTests namespace:(NSString *)ns packages:(NSArray *)pkgs
                                                   withFailBlock:(ZKFailWithErrorBlock)failBlock
                                                   completeBlock:(void(^)(ZKRunTestResult *r))completeBlock;

@property (assign) BOOL debugLog;
@property (readonly) NSString *lastDebugLog;

-(ZKLogCategoryLevel)debugLevelForCategory:(ZKLogCategory)c;
-(void)setDebugLevel:(ZKLogCategoryLevel)lvl forCategory:(ZKLogCategory)c;

+(NSArray *)logLevelNames;

@end
