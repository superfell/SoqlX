// Copyright (c) 2021 Simon Fell
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

#import <Foundation/Foundation.h>
#import "ZKTextView.h"

typedef NS_OPTIONS(uint32_t, TokenType) {
    TTKeyword           = 1,
    TTFieldPath         = 1 << 1,    // fieldPath gets resolved into these components.
    TTAlias             = 1 << 2,
    TTRelationship      = 1 << 3,
    TTField             = 1 << 4,
    TTFunc              = 1 << 5,
    TTChildSelect       = 1 << 6,
    TTTypeOf            = 1 << 7,
    TTSObject           = 1 << 8,
    TTAliasDecl         = 1 << 9,
    TTSObjectRelation   = 1 << 10,
    TTOperator          = 1 << 11,
    TTSemiJoinSelect    = 1 << 12,
    TTUsingScope        = 1 << 13,
    TTDataCategory      = 1 << 14,
    TTDataCategoryValue = 1 << 15,
    TTLiteral           = 1 << 16,
    TTLiteralList       = 1 << 17,
    TTLiteralString     = 1 << 18,
    TTLiteralNumber     = 1 << 19,
    TTLiteralDate       = 1 << 20,
    TTLiteralDateTime   = 1 << 21,
    TTLiteralNamedDateTime= 1 << 22,
    TTLiteralBoolean    = 1 << 23,
    TTLiteralNull       = 1 << 24,
    TTLiteralCurrency   = 1 << 25,
    TTError             = 1 << 26,
};

NSString *tokenName(TokenType type);
NSString *tokenNames(TokenType types);

@interface Icons : NSObject
+(NSImage*)iconFor:(TokenType)t;
@end

@interface Completion : NSObject<ZKTextViewCompletion>
+(NSArray<Completion*>*)completions:(NSArray<NSString*>*)txt type:(TokenType)t;
+(instancetype)txt:(NSString*)txt type:(TokenType)t;
+(instancetype)display:(NSString*)d insert:(NSString*)i finalInsertion:(NSString*)fi type:(TokenType)t;
@property (strong, nonatomic) NSString *displayText;
@property (strong, nonatomic) NSString *nonFinalInsertionText;   // the insertion text to use before confirmation.
@property (strong, nonatomic) NSString *finalInsertionText;      // the insertion text to use when confirmed as the completion to use.
@property (copy,   nonatomic) CompletionCallback onFinalInsert;  // callback to customize outcome of final insertion.
@property (assign, nonatomic) TokenType type;
@property (strong, nonatomic) NSImage *icon;                    // will default to Icons.iconFor:(Type) if not set.
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
-(void)addTokens:(NSArray<Token*>*)t;
-(void)removeToken:(Token*)t;
-(NSInteger)count;
// remove the range of tokens from the tokens array and return then in a new collection of their own.
-(Tokens*)cutRange:(NSRange)r;
// remove the set of tokens that overlap with the supplied positon range and return then in a new collection of their own.
-(Tokens*)cutPositionRange:(NSRange)r;
@end

CompletionCallback moveSelection(NSInteger amount);
