//
//  SoqlFunction.h
//  SoqlXplorer
//
//  Created by Simon Fell on 4/27/21.
//

#import <Foundation/Foundation.h>
#import "SoqlToken.h"

@class CaseInsensitiveStringKey;

@interface SoqlFuncArg : NSObject
+(instancetype)arg:(TokenType)type ex:(NSString*)ex;
@property (assign,nonatomic) TokenType type;
@property (strong,nonatomic) NSString *exampleValue;
@end

@interface SoqlFunction : NSObject
+(NSDictionary<CaseInsensitiveStringKey*,SoqlFunction*>*)all;

+(instancetype)fn:(NSString*)name args:(NSArray<SoqlFuncArg*>*)args;
@property (strong,nonatomic) NSString *name;
@property (strong,nonatomic) NSArray<SoqlFuncArg*>* args;
@end

