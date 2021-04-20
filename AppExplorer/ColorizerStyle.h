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

@property (strong) NSColor *fieldColor;
@property (strong) NSColor *keywordColor;
@property (strong) NSColor *literalColor;
@property (strong) NSNumber *underlineStyle;
@property (strong) NSDictionary *underlined;
@property (strong) NSDictionary *noUnderline;

@property (strong) NSDictionary *keyWord;
@property (strong) NSDictionary *field;
@property (strong) NSDictionary *literal;

@end

@interface ZKDescribeSObject (Colorize)
-(NSDictionary<CaseInsensitiveStringKey*,ZKDescribeField*>*)parentRelationshipsByName;
-(NSDictionary<CaseInsensitiveStringKey*,ZKChildRelationship*>*)childRelationshipsByName;
@end
