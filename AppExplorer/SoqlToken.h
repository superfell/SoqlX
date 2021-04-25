//
//  SoqlToken.h
//  SoqlXplorer
//
//  Created by Simon Fell on 4/23/21.
//

#import <Foundation/Foundation.h>


typedef NS_ENUM(uint16_t, TokenType) {
    TTKeyword,
    TTFieldPath,    // fieldPath gets resolved into these components.
    TTAlias,
    TTRelationship,
    TTField,
    TTFunc,
    TTNestedSelect,
    TTTypeOf,
    TTSObject,
    TTAliasDecl,
    TTSObjectRelation,
    TTOperator,
    TTLiteral,
    TTLiteralList,
    TTUsingScope,
    TTDataCategory,
    TTDataCategoryValue,
    TTError
};

@interface Icons : NSObject
+(NSImage*)iconFor:(TokenType)t;
@end

@interface Completion : NSObject
+(NSArray<Completion*>*)completions:(NSArray<NSString*>*)txt type:(TokenType)t;
+(instancetype)txt:(NSString*)txt type:(TokenType)t;
+(instancetype)display:(NSString*)d insert:(NSString*)i type:(TokenType)t;
@property (strong, nonatomic) NSString *displayText;
@property (strong, nonatomic) NSString *insertionText;
@property (assign, nonatomic) TokenType type;
-(NSImage*)icon;
@end


@interface Token : NSObject {
    NSString *txt;
}
+(instancetype)txt:(NSString *)fullString loc:(NSRange)tokenLoc;
@property (assign,nonatomic) TokenType type;
@property (assign,nonatomic) NSRange loc;
@property (strong,nonatomic) NSObject *value;
@property (strong,nonatomic) NSMutableArray<Completion*>* completions;
@property (strong,nonatomic) NSString *tokenTxt;

-(BOOL)matches:(NSString *)match caseSensitive:(BOOL)cs;
// Creates another Token from the same backing string.
-(Token*)tokenOf:(NSRange)r;
@end

@interface Tokens : NSObject
@property (strong,readonly,nonatomic) NSArray<Token*>* tokens;
-(void)addToken:(Token*)t;
-(void)removeToken:(Token*)t;
-(NSInteger)count;
@end
