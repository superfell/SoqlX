//
//  SoqlParser.m
//  ZKParser
//
//  Created by Simon Fell on 4/9/21.
//  Copyright © 2021 Simon Fell. All rights reserved.
//

#import "SoqlParser.h"
#import "ZKParserFactory.h"
#import "SoqlToken.h"

const NSString *KeyTokens = @"tokens";
const NSString *KeySoqlText = @"soql";



@interface SoqlParser()
@property (strong,nonatomic) ZKBaseParser *parser;
@end

@implementation SoqlParser

-(instancetype)init {
    self = [super init];
    self.parser = [self buildParser:nil];
    return self;
}

-(void)setDebugOutputTo:(NSString*)filename {
    self.parser = [self buildParser:filename];
}

-(NSArray<Token*>*)parse:(NSString *)input error:(NSError**)err {
    NSDictionary *ctx = @{KeyTokens: [Tokens new],
                          KeySoqlText:input,
    };
    ZKParsingState *state = [ZKParsingState withInput:input];
    state.userContext = ctx;
    [state parse:self.parser error:err];
    return ctx[KeyTokens];
}

-(ZKBaseParser*)literalStringValue:(ZKParserFactory*)f {
    ZKBaseParser *p = [f fromBlock:^ZKParserResult *(ZKParsingState *input, NSError *__autoreleasing *err) {
        NSInteger start = input.pos;
        if ((!input.hasMoreInput) || input.currentChar != '\'') {
            *err = [NSError errorWithDomain:@"Soql"
                                      code:1
                                  userInfo:@{
                                      NSLocalizedDescriptionKey:[NSString stringWithFormat:@"expecting ' at position %lu", input.pos+1],
                                      @"Position": @(input.pos+1)
                                  }];
            return nil;
        }
        input.pos++;
        [input markCut];
        while (true) {
            if (!input.hasMoreInput) {
                *err = [NSError errorWithDomain:@"Soql"
                                          code:1
                                      userInfo:@{
                                          NSLocalizedDescriptionKey:[NSString stringWithFormat:@"reached end of input while parsing a string literal, missing closing ' at %lu", input.pos],
                                          @"Position": @(input.pos)
                                      }];
                return nil;
            }
            unichar c = input.currentChar;
            if (c == '\\') {
                input.pos++;
                if (!input.hasMoreInput) {
                    *err = [NSError errorWithDomain:@"Soql"
                                              code:1
                                          userInfo:@{
                                              NSLocalizedDescriptionKey:[NSString stringWithFormat:@"invalid escape sequence at %lu", input.pos],
                                              @"Position": @(input.pos)
                                          }];
                }
                input.pos++;
                continue;
            }
            input.pos++;
            if (c == '\'') {
                break;
            }
        }
        // range includes the ' tokens, the value does not.
        NSRange overalRng = NSMakeRange(start,input.pos-start);
        Token *t = [Token txt:input.input loc:overalRng];
        t.type = TTLiteralString;
        return [ZKParserResult result:t ctx:input.userContext loc:overalRng];
    }];
    p.debugName = @"Literal String";
    return p;
}

-(ZKBaseParser*)literalValue:(ZKParserFactory*)f {
    ZKBaseParser *literalStringValue = [self literalStringValue:f];
    ZKBaseParser *literalNullValue = [f onMatch:[f eq:@"null"] perform:^ZKParserResult *(ZKParserResult *r) {
        Token *t = [Token txt:r.userContext[KeySoqlText] loc:r.loc];
        t.type = TTLiteralNull;
        t.value = [NSNull null];
        r.val = t;
        return r;
    }];
    ZKBaseParser *literalTrueValue = [f onMatch:[f eq:@"true"] perform:^ZKParserResult *(ZKParserResult *r) {
        Token *t = [Token txt:r.userContext[KeySoqlText] loc:r.loc];
        t.type = TTLiteralBoolean;
        t.value = @TRUE;
        r.val = t;
        return r;
    }];
    ZKBaseParser *literalFalseValue = [f onMatch:[f eq:@"false"] perform:^ZKParserResult *(ZKParserResult *r) {
        Token *t = [Token txt:r.userContext[KeySoqlText] loc:r.loc];
        t.type = TTLiteralBoolean;
        t.value = @FALSE;
        r.val = t;
        return r;
    }];
    ZKBaseParser *literalNumberValue = [f onMatch:[f decimalNumber] perform:^ZKParserResult *(ZKParserResult *r) {
        Token *t = [Token txt:r.userContext[KeySoqlText] loc:r.loc];
        t.type = TTLiteralNumber;
        t.value = r.val;
        r.val = t;
        return r;
    }];
    NSError *err = nil;
    NSRegularExpression *dateTime = [NSRegularExpression regularExpressionWithPattern:@"\\d\\d\\d\\d-\\d\\d-\\d\\d(?:T\\d\\d:\\d\\d:\\d\\d(?:Z|[+-]\\d\\d:\\d\\d))?"
                                                                              options:NSRegularExpressionCaseInsensitive
                                                                                error:&err];
    NSAssert(err == nil, @"failed to compile regex %@", err);
    NSISO8601DateFormatter *dfDateTime = [NSISO8601DateFormatter new];
    NSISO8601DateFormatter *dfDate = [NSISO8601DateFormatter new];
    dfDate.formatOptions = NSISO8601DateFormatWithFullDate | NSISO8601DateFormatWithDashSeparatorInDate;
    ZKBaseParser *literalDateTimeValue = [f onMatch:[f regex:dateTime name:@"date/time literal"] perform:^ZKParserResult *(ZKParserResult *r) {
        Token *t = [Token txt:r.userContext[KeySoqlText] loc:r.loc];
        NSString *dt = r.val;
        if (dt.length == 10) {
            t.value = [dfDate dateFromString:dt];
            t.type = TTLiteralDate;
        } else {
            t.value = [dfDateTime dateFromString:dt];
            t.type = TTLiteralDateTime;
        }
        r.val = t;
        return r;
    }];
    NSRegularExpression *currency = [NSRegularExpression regularExpressionWithPattern:@"[a-z]{3}\\d+(?:\\.\\d+)?"
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:&err];
    NSAssert(err == nil, @"failed to compile regex %@", err);
    ZKBaseParser *literalCurrency = [f onMatch:[f regex:currency name:@"currency"] perform:^ZKParserResult *(ZKParserResult *r) {
        Token *t = [Token txt:r.userContext[KeySoqlText] loc:r.loc];
        t.type = TTLiteralCurrency;
        t.value = r.val;
        r.val = t;
        return r;
    }];

    NSRegularExpression *token = [NSRegularExpression regularExpressionWithPattern:@"[a-z][a-z0-9:_\\-\\.]*"
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:&err];
    NSAssert(err == nil, @"failed to compile regex %@", err);
    ZKBaseParser *literalToken = [f onMatch:[f regex:token name:@"named literal"] perform:^ZKParserResult *(ZKParserResult *r) {
        Token *t = [Token txt:r.userContext[KeySoqlText] loc:r.loc];
        t.type = TTLiteralNamedDateTime;
        t.value = r.val;
        r.val = t;
        return r;
    }];
    ZKBaseParser *literalValue = [f onMatch:[f firstOf:@[literalStringValue, literalNullValue, literalTrueValue, literalFalseValue, literalDateTimeValue,
                                                         literalNumberValue, literalCurrency, literalToken]] perform:^ZKParserResult *(ZKParserResult *r) {
            [r.userContext[KeyTokens] addToken:r.val];
            return r;
    }];
    literalValue.debugName = @"LiteralVal";
    return literalValue;
}

-(ZKBaseParser*)buildParser:(NSString*)debugFilename {
    ZKParserFactory *f = [ZKParserFactory new];
    if (debugFilename.length > 0) {
        f.debugFile = debugFilename;
    }
    f.defaultCaseSensitivity = CaseInsensitive;

    ZKBaseParser* ws = [f characters:[NSCharacterSet whitespaceAndNewlineCharacterSet] name:@"whitespace" min:1];
    ZKBaseParser* maybeWs = [f characters:[NSCharacterSet whitespaceAndNewlineCharacterSet] name:@"whitespace" min:0];
    ZKBaseParser* cut = [f cut];
    
    // constructs a seq parser for each whitespace separated token, e.g. given input "NULLS LAST" will generate
    // seq:"NULLS", ws, "LAST".
    ZKBaseParser*(^tokenSeqType)(NSString*,TokenType) = ^ZKBaseParser*(NSString *t, TokenType type) {
        NSArray<NSString*>* tokens = [t componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSMutableArray *seq = [NSMutableArray arrayWithCapacity:tokens.count *2];
        NSEnumerator *e = [tokens objectEnumerator];
        [seq addObject:[f eq:[e nextObject]]];
        do {
            NSString *next = [e nextObject];
            if (next == nil) break;
            [seq addObject:ws];
            [seq addObject:[f eq:next]];
        } while(true);
        ZKBaseParser *p = seq.count == 1 ? seq[0] : [f seq:seq];
        return [f onMatch:p perform:^ZKParserResult*(ZKParserResult*r) {
            Token *tkn = [Token txt:r.userContext[KeySoqlText] loc:r.loc];
            tkn.type = type;
            tkn.value = t;
            r.val = tkn;
            [r.userContext[KeyTokens] addToken:tkn];
            return r;
        }];
    };
    ZKBaseParser*(^tokenSeq)(NSString*) = ^ZKBaseParser*(NSString *t) {
        return tokenSeqType(t, TTKeyword);
    };
    // Completions can be nil, in which case they'll be autogenerated from the supplied token type & tokens.
    ZKBaseParser*(^oneOfTokensWithCompletions)(TokenType, NSArray<NSString*>*, NSArray<Completion*>*, BOOL) =
        ^ZKBaseParser*(TokenType type, NSArray<NSString*>* tokens, NSArray<Completion*>*completions, BOOL addTokenToContext) {
        
        if (completions == nil) {
            completions = [Completion completions:tokens type:type];
        }
        ZKBaseParser *p = [f oneOfTokensList:tokens];
        p = [f onError:p perform:^(NSError *__autoreleasing *err) {
            NSInteger pos = [(*err).userInfo[@"Position"] integerValue];
            *err = [NSError errorWithDomain:@"Parser" code:33 userInfo:@{
                NSLocalizedDescriptionKey:[NSString stringWithFormat:@"expecting one of %@ at position %lu",
                                           [tokens componentsJoinedByString:@","], pos],
                @"Position": @(pos),
                @"Completions" : completions
            }];
        }];
        p = [f onMatch:p perform:^ZKParserResult *(ZKParserResult *r) {
            Token *t = [Token txt:r.userContext[KeySoqlText] loc:r.loc];
            t.type = type;
            [t.completions addObjectsFromArray:completions];
            r.val = t;
            if (addTokenToContext) {
                [r.userContext[KeyTokens] addToken:t];
            }
            return r;
        }];
        return p;
    };
    ZKBaseParser* commaSep = [f seq:@[maybeWs, [f eq:@","], maybeWs]];
    ZKBaseParser* identHead = [f characters:[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"]
                               name:@"identifier"
                                min:1];
    ZKBaseParser* identTail = [f characters:[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_"]
                               name:@"identifier"
                                min:0];
    ZKBaseParser *ident = [f onMatch:[f seq:@[identHead, identTail]] perform:^ZKParserResult *(ZKParserResult *r) {
        if (![r childIsNull:1]) {
            r.val = [NSString stringWithFormat:@"%@%@", [[r child:0] val], [[r child:1] val]];
        } else {
            r.val = [[r child:0] val];
        }
        return r;
    }];
    ident.debugName = @"ident";
    
    // SELECT LIST
    ZKParserRef *selectStmt = [f parserRef];

    // USING is not in the doc, but appears to not be allowed
    // ORDER & OFFSET are issues for our parser, but not the sfdc one.
    NSSet<NSString*> *keywords = [NSSet setWithArray:[@"ORDER OFFSET USING AND ASC DESC EXCLUDES FIRST FROM GROUP HAVING IN INCLUDES LAST LIKE LIMIT NOT NULL NULLS OR SELECT WHERE WITH" componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
    ZKBaseParser *aliasOnly = [f zeroOrOne:[f onMatch:[f seq:@[ws, ident]] perform:pick(1)]];
    ZKBaseParser *alias = [f fromBlock:^ZKParserResult *(ZKParsingState *input, NSError *__autoreleasing *err) {
        NSInteger start = input.pos;
        ZKParserResult *r = [aliasOnly parse:input error:err];
        if (r.val != [NSNull null]) {
            NSString *txt = [r.val uppercaseString];
            if ([keywords containsObject:txt]) {
                [input moveTo:start];
                *err = nil;
                return [ZKParserResult result:[NSNull null] ctx:input.userContext loc:r.loc];
            }
            Token *t = [Token txt:r.userContext[KeySoqlText] loc:r.loc];
            t.type = TTAliasDecl;
            [r.userContext[KeyTokens] addToken:t];
            r.val = t;
        }
        return r;
    }];
    ZKBaseParser* fieldPath = [f onMatch:[f oneOrMore:ident separator:[f eq:@"."]] perform:^ZKParserResult *(ZKParserResult *r) {
        Token *t = [Token txt:r.userContext[KeySoqlText] loc:r.loc];
        t.type = TTFieldPath;
        t.value = r.childVals;
        [r.userContext[KeyTokens] addToken:t];
        r.val = t;
        return r;
    }];
    fieldPath.debugName = @"fieldPath";
    
    ZKBaseParser* fieldAndAlias = [f seq:@[fieldPath, alias]];
    fieldAndAlias.debugName = @"field";
    
    ZKBaseParser *literalValue = [self literalValue:f];

    ZKParserRef *fieldOrFunc = [f parserRef];
    ZKBaseParser* func = [f onMatch:[f seq:@[ident,
                              maybeWs,
                              [f eq:@"("],
                              cut,
                              maybeWs,
                              [f zeroOrMore:[f firstOf:@[fieldOrFunc,literalValue]] separator:commaSep],
                              maybeWs,
                              [f eq:@")"],
                              alias
                            ]] perform:^ZKParserResult*(ZKParserResult*r) {
        Token *fn = [Token txt:r.userContext[KeySoqlText] loc:[[r child:0] loc]];
        fn.type = TTFunc;
        Tokens *tk = r.userContext[KeyTokens];
        fn.value = [tk cutPositionRange:NSUnionRange([[r child:0] loc], [[r child:7] loc])]; // doesn't include alias
        [tk addToken:fn];
        return r;
    }];
    func.debugName = @"func";
    // TODO, add onError handler that changes the error message to expected field, func or literal value. needs errorCodes sorting out
    
    fieldOrFunc.parser = [f firstOf:@[func, fieldAndAlias]];
    
    ZKBaseParser *nestedSelectStmt = [f onMatch:[f seq:@[[f eq:@"("], selectStmt, [f eq:@")"]]] perform:^ZKParserResult*(ZKParserResult*r) {
        Token *t = [Token txt:r.userContext[KeySoqlText] loc:r.loc];
        t.type = TTChildSelect;
        [r.userContext[KeyTokens] addToken:t];
        // TODO, cut child tokens out into value here?
        r.val = t;
        return r;
    }];
    nestedSelectStmt.debugName = @"NestedSelect";
    ZKBaseParser *typeOfWhen = [f onMatch:[f seq:@[tokenSeq(@"WHEN"), cut, ws, ident, ws, tokenSeq(@"THEN"), ws,
                                         [f oneOrMore:fieldPath separator:commaSep]]] perform:^ZKParserResult *(ZKParserResult *r) {
        Token *t = [Token txt:r.userContext[KeySoqlText] loc:[[r child:3] loc]];
        t.type = TTSObject;
        [r.userContext[KeyTokens] addToken:t];
        return r;
    }];
    ZKBaseParser *typeOfElse = [f seq:@[tokenSeq(@"ELSE"), ws, [f oneOrMore:fieldPath separator:commaSep]]];
    ZKBaseParser *typeofRel = [f onMatch:ident perform:^ZKParserResult *(ZKParserResult *r) {
        Token *t = [Token txt:r.userContext[KeySoqlText] loc:r.loc];
        t.type = TTRelationship;
        [r.userContext[KeyTokens] addToken:t];
        return r;
    }];
    ZKBaseParser *typeOf = [f onMatch:[f seq:@[
                                tokenSeq(@"TYPEOF"), cut, ws,
                                typeofRel, ws,
                                [f oneOrMore:typeOfWhen separator:ws], maybeWs,
                                [f zeroOrOne:typeOfElse], maybeWs,
                                tokenSeq(@"END")]] perform:^ZKParserResult *(ZKParserResult *r) {
        Token *t = [Token txt:r.userContext[KeySoqlText] loc:r.loc];
        t.type = TTTypeOf;
        [r.userContext[KeyTokens] addToken:t];
        return r;
    }];
    typeOf.debugName = @"typeOf";
    typeOfWhen.debugName = @"typeOfWhen";
    typeOfElse.debugName = @"typeOfElse";
    
    ZKBaseParser* selectExprs = [f oneOrMore:[f firstOf:@[func, typeOf, fieldAndAlias, nestedSelectStmt]] separator:commaSep];
    selectExprs.debugName = @"selectExprs";

    /// FROM
    ZKBaseParser *objectRef = [f onMatch:[f seq:@[ident, alias]] perform:^ZKParserResult *(ZKParserResult *r) {
        Token *t = [Token txt:r.userContext[KeySoqlText] loc:[[r child:0] loc]];
        t.type = TTSObject;
        [r.userContext[KeyTokens] addToken:t];
        // alias was already taken care of by the alias parser.
        return r;
    }];
    ZKBaseParser *objectRefs = [f onMatch:[f seq:@[objectRef, [f zeroOrOne:
                                         [f onMatch:[f seq:@[commaSep, [f oneOrMore:fieldAndAlias separator:commaSep]]] perform:pick(1)]]]]
                          perform:^ZKParserResult *(ZKParserResult*r) {
        
        // The tokens generated by fieldAndAlias have the wrong type in this case.
        if (![r childIsNull:1]) {
            // rels is the array of fieldAndAliases
            NSArray<ZKParserResult*>* rels = [[[r child:1] val] valueForKey:@"val"];
            for (NSArray<ZKParserResult*>*fieldAndAlias in rels) {
                // each fieldAndAlias has 2 children, one for field & one for alias.
                if ([fieldAndAlias[0].val isKindOfClass:[Token class]]) {
                    Token *t = (Token*)fieldAndAlias[0].val;
                    t.type = TTSObjectRelation;
                }
            }
        }
        return r;
    }];
    
    /// WHERE
    NSArray<Completion*>* opCompletions = [Completion completions:@[@"<",@"<=",@">",@">=", @"=", @"!=", @"LIKE",@"INCLUDES",@"EXCLUDES",@"IN"] type:TTOperator];
    Completion *compNotIn = [Completion txt:@"NOT IN" type:TTOperator];
    compNotIn.nonFinalInsertionText = @"NOT_IN";
    compNotIn.finalInsertionText = @"NOT IN";
    opCompletions = [opCompletions arrayByAddingObject:compNotIn];
    ZKBaseParser *operator = oneOfTokensWithCompletions(TTOperator,@[@"<",@"<=",@">",@">=",@"=",@"!=",@"LIKE"],opCompletions, TRUE);
    ZKBaseParser *opIncExcl = oneOfTokensWithCompletions(TTOperator,@[@"INCLUDES",@"EXCLUDES"], opCompletions, TRUE);
    ZKBaseParser *inOrNotIn = [f oneOf:@[tokenSeqType(@"IN", TTOperator), tokenSeqType(@"NOT IN", TTOperator)]];
    ZKBaseParser *opInNotIn = [f fromBlock:^ZKParserResult *(ZKParsingState *input, NSError *__autoreleasing *err) {
        ZKParserResult *r = [inOrNotIn parse:input error:err];
        if (*err == nil) {
            [[r.val completions] addObjectsFromArray:[Completion completions:@[@"IN",@"NOT IN"] type:TTOperator]];
        } else {
            *err = [NSError errorWithDomain:@"Parser" code:33 userInfo:@{
                NSLocalizedDescriptionKey:[NSString stringWithFormat:@"expecting one of %@ at position %lu",
                                           [[opCompletions valueForKey:@"displayText"] componentsJoinedByString:@","], input.pos+1],
                @"Position": @(input.pos+1),
                @"Completions" : opCompletions
            }];
        }
        return r;
    }];
    opInNotIn.debugName=@"In/NotIn";
    ZKBaseParser *literalList = [f seq:@[[f eq:@"("], maybeWs,
                                        [f oneOrMore:literalValue separator:commaSep],
                                         maybeWs, [f eq:@")"]]];

    ZKBaseParser *semiJoinValues = [f onMatch:[f firstOf:@[nestedSelectStmt, literalList]] perform:^ZKParserResult *(ZKParserResult *r) {
        if ([r.val isKindOfClass:[Token class]]) {
            Token *t = r.val;
            if (t.type == TTChildSelect) {
                t.type = TTSemiJoinSelect;
            }
        }
        return r;
    }];
    ZKBaseParser *operatorRHS = [f firstOf:@[
        [f seq:@[operator, cut, maybeWs, literalValue]],
        [f seq:@[opIncExcl, cut, maybeWs, literalList]],
        [f seq:@[opInNotIn, cut, maybeWs, semiJoinValues]]]];

    ZKBaseParser *baseExpr = [f seq:@[fieldOrFunc, maybeWs, operatorRHS]];

    // use parserRef so that we can set up the recursive decent for x op y and (y op z or z op t)
    // be careful not to use oneOf with it as that will recurse infinitly because it checks all branches.
    ZKParserRef *exprList = [f parserRef];
    ZKBaseParser *parensExpr = [f onMatch:[f seq:@[[f eq:@"("], maybeWs, exprList, maybeWs, [f eq:@")"]]] perform:pick(2)];

    // we don't want to add the and/or token to context as soon as possible because OR is ambigious with ORDER BY. we need to wait til we pass
    // the whitespace tests.
    ZKBaseParser *andOrToken = oneOfTokensWithCompletions(TTOperator, @[@"AND",@"OR"], nil, FALSE);
    ZKBaseParser *andOr = [f onMatch:[f seq:@[maybeWs, andOrToken, ws]] perform:^ZKParserResult*(ZKParserResult*r) {
        Token *t = [[r child:1] val];
        [r.userContext[KeyTokens] addToken:t];
        return r;
    }];
    ZKBaseParser *not = [f seq:@[tokenSeqType(@"NOT", TTOperator), maybeWs]];
    exprList.parser = [f seq:@[[f zeroOrOne:not],[f firstOf:@[parensExpr, baseExpr]], [f zeroOrOne:[f seq:@[andOr, exprList]]]]];
    
    ZKBaseParser *where = [f zeroOrOne:[f seq:@[ws ,tokenSeq(@"WHERE"), cut, ws, exprList]]];
    
    /// FILTER SCOPE
    ZKBaseParser *filterScope = [f zeroOrOne:[f onMatch:[f seq:@[ws, tokenSeq(@"USING SCOPE"), ws, ident]] perform:^ZKParserResult*(ZKParserResult*r) {
        Token *t = [Token txt:r.userContext[KeySoqlText] loc:[[r child:3] loc]];
        t.type = TTUsingScope;
        [r.userContext[KeyTokens] addToken:t];
        return r;
    }]];

    /// DATA CATEGORY
    ZKBaseParser *aCategory = [f onMatch:ident perform:^ZKParserResult*(ZKParserResult*r) {
        Token *t = [Token txt:r.userContext[KeySoqlText] loc:r.loc];
        t.type = TTDataCategoryValue;
        [r.userContext[KeyTokens] addToken:t];
        return r;
    }];
    ZKBaseParser *catList = [f seq:@[[f eq:@"("], maybeWs, [f oneOrMore:aCategory separator:commaSep], maybeWs, [f eq:@")"]]];
    ZKBaseParser *catFilterVal = [f firstOf:@[catList, aCategory]];
    
    NSArray<NSString*>* catOperators = @[@"AT", @"ABOVE", @"BELOW", @"ABOVE_OR_BELOW"];
    ZKBaseParser *catFilter = [f onMatch:[f seq:@[ident, ws, oneOfTokensWithCompletions(TTKeyword, catOperators, nil, TRUE), cut, maybeWs, catFilterVal]] perform:^ZKParserResult*(ZKParserResult*r) {
        Token *t = [Token txt:r.userContext[KeySoqlText] loc:[[r child:0] loc]];
        t.type = TTDataCategory;
        [r.userContext[KeyTokens] addToken:t];
        return r;
    }];
    ZKBaseParser *withDataCat = [f zeroOrOne:[f seq:@[ws, tokenSeq(@"WITH DATA CATEGORY"), cut, ws,
                                                       [f oneOrMore:catFilter separator:[f seq:@[ws,tokenSeqType(@"AND",TTOperator),ws]]]]]];
    
    /// GROUP BY
    ZKBaseParser *groupBy = [f seq:@[ws, tokenSeq(@"GROUP BY"), cut, ws, [f oneOrMore:fieldOrFunc separator:commaSep]]];
    ZKBaseParser *groupByFieldList = [f seq:@[[f eq:@"("], maybeWs, [f oneOrMore:fieldOrFunc separator:commaSep], maybeWs, [f eq:@")"]]];
    ZKBaseParser *groupByRollup = [f seq:@[ws, tokenSeq(@"GROUP BY ROLLUP"), cut, maybeWs, groupByFieldList]];
    ZKBaseParser *groupByCube = [f seq:@[ws, tokenSeq(@"GROUP BY CUBE"), cut, maybeWs, groupByFieldList]];
    
    ZKBaseParser *having = [f zeroOrOne:[f seq:@[ws ,tokenSeq(@"HAVING"), cut, ws, exprList]]];
    ZKBaseParser *groupByClause = [f zeroOrOne:[f seq:@[[f firstOf:@[groupByRollup, groupByCube, groupBy]], having]]];
    
    /// ORDER BY
    ZKBaseParser *ascDesc = [f seq:@[ws, oneOfTokensWithCompletions(TTKeyword, @[@"ASC",@"DESC"], nil, TRUE)]];
    ZKBaseParser *nulls = [f seq:@[ws, tokenSeq(@"NULLS"), ws, oneOfTokensWithCompletions(TTKeyword, @[@"FIRST",@"LAST"],nil, TRUE)]];
                                
    ZKBaseParser *orderByField = [f seq:@[fieldOrFunc, [f zeroOrOne:ascDesc], [f zeroOrOne:nulls]]];
    ZKBaseParser *orderByFields = [f zeroOrOne:[f seq:@[maybeWs, tokenSeq(@"ORDER BY"), cut, ws, [f oneOrMore:orderByField separator:commaSep]]]];
                                   
    ZKBaseParser *limit = [f zeroOrOne:[f onMatch:[f seq:@[maybeWs, tokenSeq(@"LIMIT"), cut, maybeWs, [f integerNumber]]] perform:^ZKParserResult*(ZKParserResult*r) {
        Token *t = [Token txt:r.userContext[KeySoqlText] loc:[[r child:4] loc]];
        t.type = TTLiteralNumber;
        t.value = r.val;
        [r.userContext[KeyTokens] addToken:t];
        return r;
    }]];
    ZKBaseParser *offset= [f zeroOrOne:[f onMatch:[f seq:@[maybeWs, tokenSeq(@"OFFSET"), cut, maybeWs, [f integerNumber]]] perform:^ZKParserResult*(ZKParserResult*r) {
        Token *t = [Token txt:r.userContext[KeySoqlText] loc:[[r child:4] loc]];
        t.type = TTLiteralNumber;
        t.value = r.val;
        [r.userContext[KeyTokens] addToken:t];
        return r;
    }]];

    ZKBaseParser *forView = [f zeroOrOne:[f seq:@[maybeWs, tokenSeq(@"FOR"), cut, ws, oneOfTokensWithCompletions(TTKeyword, @[@"VIEW",@"REFERENCE"], nil, TRUE)]]];
    ZKBaseParser *updateTracking = [f zeroOrOne:[f seq:@[maybeWs, tokenSeq(@"UPDATE"), cut, ws,
                                                         oneOfTokensWithCompletions(TTKeyword, @[@"TRACKING", @"VIEWSTAT"],nil, TRUE)]]];

    /// SELECT
    selectStmt.parser = [f seq:@[maybeWs, tokenSeq(@"SELECT"), ws, selectExprs, ws, tokenSeq(@"FROM"), ws, objectRefs,
                                  filterScope, where, withDataCat, groupByClause, orderByFields, limit, offset, forView, updateTracking, maybeWs]];
    selectStmt.debugName = @"SelectStmt";
    return selectStmt;
}

@end
