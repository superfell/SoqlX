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

#import "SoqlToken.h"

NSString *tokenName(TokenType type) {
    switch (type) {
        case TTKeyword: return @"Keyword";
        case TTFieldPath: return @"FieldPath";
        case TTAlias: return @"Aias";
        case TTRelationship: return @"Relationship";
        case TTField: return @"Field";
        case TTFunc: return @"Function";
        case TTChildSelect: return @"ChildSelect";
        case TTTypeOf: return @"TypeOf";
        case TTSObject: return @"SObject";
        case TTAliasDecl: return @"AliasDecl";
        case TTSObjectRelation: return @"RelatedSObj";
        case TTOperator: return @"Op";
        case TTSemiJoinSelect: return @"SemiJoinSelect";
        case TTUsingScope: return @"Scope";
        case TTDataCategory: return @"Category";
        case TTDataCategoryValue: return @"CategoryVal";
        case TTLiteral: return @"Literal";
        case TTLiteralList: return @"LiteralList";
        case TTLiteralString:return @"String";
        case TTLiteralNumber:return @"Number";
        case TTLiteralDate: return @"Date";
        case TTLiteralDateTime:return @"DateTime";
        case TTLiteralNamedDateTime:return @"NamedDateTime";
        case TTLiteralBoolean: return @"Boolean";
        case TTLiteralNull: return @"Null";
        case TTError: return @"Error";
        case TTLiteralCurrency: return @"Currency";
    }
    return @"<unknown>";
}

NSString *tokenNames(TokenType types) {
    NSMutableArray<NSString*> *names = [NSMutableArray arrayWithCapacity:2];
    for (TokenType m = 1; m < TTError; m = m << 1) {
        if ((types & m) != 0) {
            [names addObject:tokenName(m)];
        }
    }
    return [names componentsJoinedByString:@","];
}

@implementation Token
+(instancetype)locOnly:(NSRange)r {
    Token *tkx = [self new];
    tkx.loc = r;
    return tkx;
}

+(instancetype)txt:(NSString *)txt loc:(NSRange)r {
    NSAssert(r.location+r.length <= txt.length, @"Token location out of range of string");
    Token *tkx = [self new];
    tkx->txt = txt;
    tkx.loc = r;
    tkx.completions = [NSMutableArray array];
    return tkx;
}
-(NSString *)tokenTxt {
    if (_tokenTxt == nil) {
        _tokenTxt = [self->txt substringWithRange:self.loc];
    }
    return _tokenTxt;
}

-(BOOL)matches:(NSString *)match caseSensitive:(BOOL)cs {
    if (cs) {
        return [self.tokenTxt isEqualToString:match];
    }
    return [self.tokenTxt caseInsensitiveCompare:match] == NSOrderedSame;
}

-(BOOL)matches:(NSString *)match {
    return [self.tokenTxt caseInsensitiveCompare:match] == NSOrderedSame;
}

-(NSString *)dump:(NSInteger)depth {
    NSString *indent = [@"" stringByPaddingToLength:depth *4 withString:@" " startingAtIndex:0];
    NSString *t = [NSString stringWithFormat:@"%@%4lu-%-4lu: %@ %@ completions %lu %@", indent, self.loc.location, self.loc.length,
            [self.typeName stringByPaddingToLength:15 withString:@" " startingAtIndex:0],
            [self.tokenTxt stringByPaddingToLength:30 withString:@" " startingAtIndex:0], (unsigned long)self.completions.count,
             self.type == TTError ? self.value : @""];
    if (self.type == TTChildSelect || self.type == TTSemiJoinSelect || self.type == TTTypeOf || self.type == TTFunc || self.type == TTFieldPath) {
        NSMutableString *c = [NSMutableString string];
        [c appendString:t];
        if ([self.value isKindOfClass:[Tokens class]]) {
            Tokens *children = (Tokens*)self.value;
            for (Token *t in children.tokens) {
                [c appendString:@"\n"];
                [c appendString:[t dump:depth+1]];
            }
        } else if ([self.value isKindOfClass:[NSArray class]]) {
            // an unresolve fieldPath can have an array of strings as its value
            NSArray *strings = (NSArray*)self.value;
            [c appendFormat:@"\n%@              strings:%@", indent, [strings componentsJoinedByString:@","]];
        }
        return c;
    }
    return t;
}

-(NSString*)typeName {
    return tokenName(self.type);
}

-(Token*)tokenOf:(NSRange)r {
    return [Token txt:txt loc:r];
}

@end

@interface Tokens()
@property (strong,nonatomic) NSMutableArray<Token*> *items;
@end

@implementation Tokens

-(instancetype)init {
    self = [super init];
    self.items = [NSMutableArray arrayWithCapacity:10];
    return self;
}

// This is a range of tokens in the tokens array, not a positional range.
-(Tokens*)cutRange:(NSRange)r {
    Tokens *s = [Tokens new];
    [s.items addObjectsFromArray:[self.items subarrayWithRange:r]];
    [self.items removeObjectsInRange:r];
    return s;
}

-(Tokens*)cutPositionRange:(NSRange)r {
    if (self.tokens.count == 0) {
        return [Tokens new];
    }
    NSUInteger startIdx = [self.items indexOfObject:[Token locOnly:r]
                                    inSortedRange:NSMakeRange(0, self.items.count)
                                          options:NSBinarySearchingInsertionIndex | NSBinarySearchingFirstEqual
                                  usingComparator:compareTokenPos];
    NSUInteger end = startIdx;
    for(; end < self.tokens.count && NSLocationInRange(self.tokens[end].loc.location, r); end++) {
    }
    return [self cutRange:NSMakeRange(startIdx, end-startIdx)];
}

-(NSInteger)count {
    return self.items.count;
}

-(NSArray<Token*>*) tokens {
    return self.items;
}

// compare tokens based on their position in the source text.
NSComparator compareTokenPos = ^NSComparisonResult(id _Nonnull obj1, id _Nonnull obj2) {
    Token *a = obj1;
    Token *b = obj2;
    // Tokens are sorted by ascending starting location. For cases where there are multiple
    // tokens at the same starting location, there are sorted longest to shortest.
    if (a.loc.location == b.loc.location) {
        if (a.loc.length < b.loc.length) {
            return NSOrderedDescending;
        } else if (a.loc.length > b.loc.length) {
            return NSOrderedAscending;
        }
        return NSOrderedSame;
    }
    if (a.loc.location > b.loc.location) {
        return NSOrderedDescending;
    }
    return NSOrderedAscending;
};

-(void)addToken:(Token*)t {
    NSRange searchRange = NSMakeRange(0, self.items.count);
    NSUInteger findIndex = [self.items indexOfObject:t
                                        inSortedRange:searchRange
                                              options:NSBinarySearchingInsertionIndex | NSBinarySearchingFirstEqual
                                      usingComparator:compareTokenPos];
    [self.items insertObject:t atIndex:findIndex];
}

-(void)addTokens:(NSArray<Token*>*)tokens {
    for (Token *t in tokens) {
        [self addToken:t];
    }
}

-(void)removeToken:(Token*)t {
    [self.items removeObject:t];
}

-(NSString *)description {
    NSMutableString *s = [NSMutableString string];
    for (Token *t in self.items) {
        [s appendString:[t dump:0]];
        [s appendString:@"\n"];
    }
    return s;
}

@end

CompletionCallback moveSelection(NSInteger amount) {
    return ^BOOL(ZKTextView *v, id<ZKTextViewCompletion> c) {
        NSRange s = v.selectedRange;
        s.location += amount;
        v.selectedRange = s;
        return TRUE;
    };
}
