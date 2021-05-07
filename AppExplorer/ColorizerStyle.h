//
//  ColorizerStyle.h
//  AppExplorer
//
//  Created by Simon Fell on 4/17/21.
//

#import <Foundation/Foundation.h>
#import <ZKSforce/ZKDescribeSObject.h>

@class CaseInsensitiveStringKey;
@class ZKDescribeField;
@class ZKChildRelationship;

@interface ColorizerStyle : NSObject
+(instancetype)styles;

@property (strong) NSColor *keywordColor;
@property (strong) NSColor *fieldColor;
@property (strong) NSColor *funcColor;
@property (strong) NSColor *sobjectColor;
@property (strong) NSColor *aliasColor;
@property (strong) NSColor *relColor;
@property (strong) NSColor *literalColor;

@property (strong) NSDictionary *underlined;

@property (strong) NSDictionary *keyword;
@property (strong) NSDictionary *field;
@property (strong) NSDictionary *func;
@property (strong) NSDictionary *relationship;
@property (strong) NSDictionary *sobject;
@property (strong) NSDictionary *alias;
@property (strong) NSDictionary *literal;

@end

@interface ZKDescribeSObject (Colorize)
-(NSDictionary<CaseInsensitiveStringKey*,ZKDescribeField*>*)parentRelationshipsByName;
-(NSDictionary<CaseInsensitiveStringKey*,ZKChildRelationship*>*)childRelationshipsByName;
@end
