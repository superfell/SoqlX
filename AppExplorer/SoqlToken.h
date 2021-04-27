//
//  SoqlToken.h
//  SoqlXplorer
//
//  Created by Simon Fell on 4/23/21.
//

#import <Foundation/Foundation.h>
#import "ZKTextView.h"

typedef NS_ENUM(uint16_t, TokenType) {
    TTKeyword,
    TTFieldPath,    // fieldPath gets resolved into these components.
    TTAlias,
    TTRelationship,
    TTField,
    TTFunc,
    TTChildSelect,
    TTTypeOf,
    TTSObject,
    TTAliasDecl,
    TTSObjectRelation,
    TTOperator,
    TTLiteral,
    TTLiteralList,
    TTSemiJoinSelect,
    TTUsingScope,
    TTDataCategory,
    TTDataCategoryValue,
    TTError
};

@interface Icons : NSObject
+(NSImage*)iconFor:(TokenType)t;
@end

@interface Completion : NSObject<ZKTextViewCompletion>
+(NSArray<Completion*>*)completions:(NSArray<NSString*>*)txt type:(TokenType)t;
+(instancetype)txt:(NSString*)txt type:(TokenType)t;
+(instancetype)display:(NSString*)d insert:(NSString*)i finalInsertion:(NSString*)fi type:(TokenType)t;
@property (strong, nonatomic) NSString *displayText;
@property (strong, nonatomic) NSString *nonFinalInsertionText;  // the insertion text to use before confirmation.
@property (strong, nonatomic) NSString *finalInsertionText;     // the insertion text to use when confirmed as the completion to use.
@property (assign, nonatomic) NSInteger finalMove;              // distance to move from the end of finalInsertionText
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

-(BOOL)matches:(NSString *)match;   // not case sensitive
-(BOOL)matches:(NSString *)match caseSensitive:(BOOL)cs;
// Creates another Token from the same backing string.
-(Token*)tokenOf:(NSRange)r;
@end

@interface Tokens : NSObject
@property (strong,readonly,nonatomic) NSArray<Token*>* tokens;
-(void)addToken:(Token*)t;
-(void)removeToken:(Token*)t;
-(NSInteger)count;
// remove the range of tokens from the tokens array and return then in a new collection of their own.
-(Tokens*)cutRange:(NSRange)r;
// remove the set of tokens that overlap with the supplied positon range and return then in a new collection of their own.
-(Tokens*)cutPositionRange:(NSRange)r;
@end
