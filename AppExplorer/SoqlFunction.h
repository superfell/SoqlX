//
//  SoqlFunction.h
//  SoqlXplorer
//
//  Created by Simon Fell on 4/27/21.
//

#import <Foundation/Foundation.h>
#import "SoqlToken.h"

@class Completion;
@class CaseInsensitiveStringKey;
@class ZKDescribeSObject;

typedef NSString*(^ExampleProvider)(ZKDescribeSObject*);

@interface SoqlFuncArg : NSObject
+(instancetype)arg:(TokenType)type ex:(ExampleProvider)ex;
@property (assign,nonatomic) TokenType type;
@property (strong,nonatomic) NSPredicate *fieldFilter;
@property (strong,nonatomic) NSPredicate *funcFilter;
@property (copy,  nonatomic) ExampleProvider example;
@end

@interface SoqlFunction : NSObject
+(NSDictionary<CaseInsensitiveStringKey*,SoqlFunction*>*)all;

+(instancetype)fn:(NSString*)name args:(NSArray<SoqlFuncArg*>*)args;

@property (strong,nonatomic) NSString *name;
@property (strong,nonatomic) NSArray<SoqlFuncArg*>* args;
-(Completion*)completionOn:(ZKDescribeSObject*)primary;
@end

