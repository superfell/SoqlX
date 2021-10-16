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

#import <objc/runtime.h>
#import "SoqlTokenizer.h"
#import "DataSources.h"
#import "CaseInsensitiveStringKey.h"
#import "ColorizerStyle.h"
#import "SoqlToken.h"
#import "Completion.h"
#import "SoqlParser.h"
#import "SoqlFunction.h"
#import "DescribeExtras.h"
#import "Prefs.h"
#import "TStamp.h"

typedef NSMutableDictionary<CaseInsensitiveStringKey*,ZKDescribeSObject*> AliasMap;

@implementation NSArray (ZKCompareStrings)
-(BOOL)containsStringIgnoringCase:(NSString *)item {
    for (NSString *v in self) {
        if ([item caseInsensitiveCompare:v] == NSOrderedSame) {
            return TRUE;
        }
    }
    return FALSE;
}
@end

@interface ContextFilters : NSObject<NSCopying>
@property (strong,nonatomic) ZKDescribeSObject *primary;
@property (assign,nonatomic) TokenType containerType;
@property (strong,nonatomic) NSPredicate *fieldCompletionsFilter;
@property (assign,nonatomic) TokenType restrictCompletionsToType;
@property (strong,nonatomic) NSPredicate *fnCompletionsFilter;
@end

@implementation ContextFilters
-(instancetype)init {
    self = [super init];
    self.restrictCompletionsToType = 0xFFFFFFFF;
    self.fnCompletionsFilter = [SoqlFunction defaultFuncFilter];
    return self;
}
- (id)copyWithZone:(nullable NSZone *)zone {
    ContextFilters *c = [ContextFilters new];
    c.primary = self.primary;
    c.containerType = self.containerType;
    c.fieldCompletionsFilter = self.fieldCompletionsFilter;
    c.restrictCompletionsToType = self.restrictCompletionsToType;
    c.fnCompletionsFilter = self.fnCompletionsFilter;
    return c;
}
@end

@interface Context : NSObject
@property (strong,nonatomic) AliasMap *aliases;

-(ContextFilters*)createChild;
-(void)popChild;
-(ContextFilters*)filter;
// executes the block with a new child filters, and then throws it away at the end
-(void)execWithChildFilters:(void(^)(ContextFilters*childFilters))block;
@end

@interface Context()
@property (strong,nonatomic) NSMutableArray<ContextFilters*>* filters;
@end

@implementation Context

-(instancetype)init {
    self = [super init];
    self.filters = [NSMutableArray arrayWithObject:[ContextFilters new]];
    return self;
}
-(ContextFilters*)filter {
    return self.filters.lastObject;
}
-(ContextFilters*)createChild {
    ContextFilters *c = [self.filters.lastObject copy];
    [self.filters addObject:c];
    return c;
}
-(void)popChild {
    NSAssert(self.filters.count > 1, @"Too many pops");
    [self.filters removeLastObject];
}
-(void)execWithChildFilters:(void(^)(ContextFilters*child))block {
    ContextFilters *c = [self createChild];
    block(c);
    [self popChild];
}
@end

// creating fn completions is called a lot, and is potentially expensive as many of them end up iterating all fields
// and gets called for every field in the query, but they only vary by object, not field, so we can cache these
typedef NSMutableDictionary<NSString *, Completion*> CompletionBySObject;

// TODO, replace with an associated field on the describe?
@interface FnCompletionsCache : NSObject
@property (strong,nonatomic) NSMutableDictionary<NSString*,CompletionBySObject*> *cache;   // fnName is the key
-(Completion*)for:(SoqlFunction*)fn onObject:(ZKDescribeSObject*)obj;
-(void)setCompletion:(Completion*)completion for:(SoqlFunction*)fn onObject:(ZKDescribeSObject*)obj;
@end

@interface SoqlTokenizer()
@property (strong,nonatomic) Tokens *tokens;
@property (strong,nonatomic) SoqlParser *soqlParser;
@property (strong,nonatomic) FnCompletionsCache *fnCompletionsCache;
@property (assign,nonatomic) BOOL coloredLastTime;
@end


@implementation SoqlTokenizer

-(instancetype)init {
    self = [super init];
    self.soqlParser = [SoqlParser new];
    self.fnCompletionsCache = [FnCompletionsCache new];
    return self;
}

-(void)setDebugOutputTo:(NSString*)filename {
    [self.soqlParser setDebugOutputTo:filename];
}

-(void)textDidChange:(NSNotification *)notification {
    [self color];
}

-(NSRange)wordAtIndex:(NSInteger)idx inString:(NSString*)txt {
    NSRange sel = NSMakeRange(idx, 0);
    for (; sel.location > 0 ; sel.location--, sel.length++) {
        unichar c = [txt characterAtIndex:sel.location-1];
        if (isblank(c) || c ==',' || c =='.' || c =='(' || c == ')') {
            break;
        }
    }
    NSInteger maxLen = txt.length - sel.location;
    for (; sel.length < maxLen; sel.length++) {
        unichar c = [txt characterAtIndex:sel.location+sel.length];
        if (isblank(c) || c ==',' || c =='.' || c =='(' || c == ')') {
            break;
        }
    }
    return sel;
}


-(void)scanWithParser:(NSString*)input {
    NSError *err = nil;
    self.tokens = [self.soqlParser parse:input error:&err];
    if (err != nil) {
        NSInteger pos = [err.userInfo[KeyPosition] integerValue];
        NSRange word = [self wordAtIndex:pos-1 inString:input];
        if (word.length == 0 && word.location > 0) {
            word.location -= 1;
            word.length += 1;
        }
        Token *t = [Token txt:input loc:word];
        t.type = TTError;
        t.value = err.localizedDescription;
        NSArray* completions = err.userInfo[KeyCompletions];
        if (completions != nil) {
            [t.completions addObjectsFromArray:completions];
        }
        [self.tokens addToken:t];
    }
}

-(Tokens*)parseAndResolve:(NSString*)soql {
    uint64_t start = mach_absolute_time();
    [self scanWithParser:soql];
    uint64_t parsed = mach_absolute_time();
    [self resolveTokens:self.tokens];
    uint64_t resolved = mach_absolute_time();
    NSLog(@"parsed %ld tokens, parse %.3fms resolve %.3fms", (long)self.tokens.count, (parsed-start) * ticksToMilliseconds, (resolved-parsed) * ticksToMilliseconds);
    //NSLog(@"resolved tokens\n%@\n", self.tokens);
    return self.tokens;
}

-(void)color {
    BOOL shouldColor = [[NSUserDefaults standardUserDefaults] boolForKey:PREF_SOQL_SYNTAX_HIGHLIGHTING];
    if (!shouldColor) {
        if (self.coloredLastTime) {
            [self removeAttributes:self.view.textStorage];
            self.coloredLastTime = FALSE;
        }
        return;
    }
    [self parseAndResolve:self.view.textStorage.string];
    NSTextStorage *txt = self.view.textStorage;
    NSRange before =  [self.view selectedRange];
    [txt beginEditing];
    [self removeAttributes:txt];
    [self applyTokens:self.tokens];
    [txt endEditing];
    [self.view setSelectedRange:before];
    self.coloredLastTime = TRUE;
}

-(void)removeAttributes:(NSTextStorage*)txt {
    NSRange all = NSMakeRange(0, txt.length);
    [txt addAttribute:NSForegroundColorAttributeName value:[NSColor textColor] range:all];
    [txt removeAttribute:NSToolTipAttributeName range:all];
    [txt removeAttribute:NSCursorAttributeName range:all];
    [txt removeAttribute:NSUnderlineStyleAttributeName range:all];
    [txt removeAttribute:KeyCompletions range:all];
}

-(void)resolveTokens:(Tokens*)tokens {
    // This is the 2nd pass that deals with resolving field/object/rel/alias/func tokens.
    // To make dealing with some items that span many tokens, we'll collect them up and
    // put then as child values instead. e.g. nested select, typeof
    for (NSInteger idx = 0; idx < tokens.count; idx++) {
        Token *t = tokens.tokens[idx];
        if (t.type == TTChildSelect || t.type == TTSemiJoinSelect || t.type == TTTypeOf) {
            NSInteger start = idx+1;
            NSInteger end = start;
            NSUInteger selEnd = t.loc.location + t.loc.length;
            for (; end < tokens.count && tokens.tokens[end].loc.location < selEnd ; end++) {
            }
            t.value = [tokens cutRange:NSMakeRange(start,end-start)];
        }
    }
    [self resolveTokens:tokens ctx:nil];
}

-(void)resolveTokens:(Tokens*)tokens ctx:(Context*)parentCtx {
    if ([tokens.tokens[0].value isEqualTo:@"SELECT"]) {
        Context *ctx = [self resolveFrom:tokens parentCtx:parentCtx];
        [self resolveTokenList:tokens ctx:ctx];
    } else {
        [self resolveSoslReturning:tokens];
    }
}

-(void)resolveTokenList:(Tokens*)tokens ctx:(Context*)ctx {
    // Check that count() is only used on its own.
    __block NSInteger selectExprCount = 0;
    __block Token *countStar = nil;
    [tokens.tokens enumerateObjectsUsingBlock:^(Token * _Nonnull sel, NSUInteger idx, BOOL * _Nonnull stop) {
        if (sel.type == TTFunc && [(Tokens*)sel.value count] == 0 && [sel.tokenTxt caseInsensitiveCompare:@"COUNT"] == NSOrderedSame) {
            countStar = sel;
        }
        if (sel.type == TTFunc || sel.type == TTField || sel.type == TTFieldPath || sel.type == TTTypeOf || sel.type == TTChildSelect) {
            selectExprCount++;
        }
        if (sel.type == TTKeyword && [sel.value isEqualTo:@"FROM"]) {
            *stop = TRUE;
        }
    }];
    if (countStar != nil && selectExprCount > 1) {
        Token *err = [countStar tokenOf:countStar.loc];
        err.type = TTError;
        err.value = @"A count() query can't select any additional fields";
        [tokens addToken:err];
    }

    NSMutableArray<Token*> *newTokens = [NSMutableArray arrayWithCapacity:4];
    NSPredicate *groupable = [NSPredicate predicateWithFormat:@"groupable=TRUE"];
    BOOL inGroupBy = FALSE;
    for (Token *sel in tokens.tokens) {
            if (!inGroupBy && (sel.type == TTKeyword) && ([sel.value isEqualTo:@"GROUP BY"] ||
                                      [sel.value isEqualTo:@"GROUP BY ROLLUP"] ||
                                      [sel.value isEqualTo:@"GROUP BY CUBE"])) {
            inGroupBy = TRUE;
            [ctx createChild].fieldCompletionsFilter = groupable;

        } else if (inGroupBy && (sel.type == TTKeyword)) {
            inGroupBy = FALSE;
            [ctx popChild];
        }
        [self resolveToken:sel new:newTokens ctx:ctx];
    }
    for (Token *t in newTokens) {
        [tokens addToken:t];
    }
    if (inGroupBy) {
        [ctx popChild];
    }
}

-(void)resolveToken:(Token*)expr new:(NSMutableArray<Token*>*)newTokens ctx:(Context*)ctx {
    switch (expr.type) {
        case TTFieldPath:
            [self resolveFieldPath:expr ctx:ctx];
            break;
        case TTFunc:
            [newTokens addObjectsFromArray:[self resolveFunc:expr ctx:ctx]];
            break;
        case TTTypeOf:
            [self resolveTypeOf:expr ctx:ctx];
            break;
        case TTChildSelect:
        case TTSemiJoinSelect: {
            [ctx execWithChildFilters:^(ContextFilters *childFilters) {
                childFilters.containerType = expr.type;
                [self resolveTokens:(Tokens*)expr.value ctx:ctx];
            }];
            break;
        }
        case TTLiteralNamedDateTime: {
                Token *err = [self resolveNamedDateTime:expr ctx:ctx];
                if (err != nil) {
                    [newTokens addObject:err];
                }
                break;
            }
        default:
            break;
    }
}

-(NSArray<Token*>*)resolveFunc:(Token*)f ctx:(Context*)ctx {
    SoqlFunction *fn = [SoqlFunction all][[CaseInsensitiveStringKey of:f.tokenTxt]];
    [self addFieldCompletionsFor:ctx.filter.primary to:f ctx:ctx];
    if (fn == nil) {
        Token *err = [f tokenOf:f.loc];
        err.type = TTError;
        err.value = [NSString stringWithFormat:@"There is no function named '%@'", f.tokenTxt];
        [self resolveTokenList:(Tokens*)f.value ctx:ctx];
        return [NSArray arrayWithObject:err];
    }
    NSMutableArray<Token*>* errors = [NSMutableArray array];
    if (ctx.filter.fnCompletionsFilter != nil && ![ctx.filter.fnCompletionsFilter evaluateWithObject:fn]) {
        Token *err = [f tokenOf:f.loc];
        err.type = TTError;
        err.value = [NSString stringWithFormat:@"The function %@ is not valid at this location", fn.name];
        [errors addObject:err];
    }
    Tokens *argTokens = (Tokens*)f.value;  
    Token *err = [fn validateArgCount:f];
    if (err != nil) {
        [errors addObject:err];
    }
    NSMutableArray *argsNewTokens = [NSMutableArray array];
    NSEnumerator<SoqlFuncArg*> *fnArgs = fn.args.objectEnumerator;
    for (Token *argToken in argTokens.tokens) {
        SoqlFuncArg *argSpec = fnArgs.nextObject;

        [ctx execWithChildFilters:^(ContextFilters *childFilters) {
            childFilters.fieldCompletionsFilter = argSpec.fieldFilter;
            childFilters.fnCompletionsFilter = argSpec.funcFilter;
            childFilters.restrictCompletionsToType = argSpec.type;
            
            [self resolveToken:argToken new:argsNewTokens ctx:ctx];
            Token *newToken = [argSpec validateToken:argToken];
            if (newToken != nil) {
                [argsNewTokens addObject:newToken];
            }
        }];
    }
    for (Token *t in argsNewTokens) {
        [argTokens addToken:t];
    }
    return errors;
}

-(void)resolveTypeOf:(Token*)typeOf ctx:(Context*)ctx {
    if (ctx.filter.primary == nil) {
        return;
    }
    NSAssert([typeOf.value isKindOfClass:[Tokens class]], @"TypeOf token should have an child tokens value");
    Tokens *tokens = (Tokens*) typeOf.value;
    NSEnumerator<Token*> *e = tokens.tokens.objectEnumerator;
    Token *t = e.nextObject;
    if (t.type == TTKeyword) t = e.nextObject;  // TYPEOF
    ZKDescribeField *relField = nil;
    if (t.type == TTRelationship) {
        BOOL found = FALSE;
        for (ZKDescribeField *f in ctx.filter.primary.fields) {
            if (f.referenceTo.count > 1 && f.relationshipName.length > 0) {
                [t.completions addObject:[Completion txt:f.relationshipName type:TTRelationship]];
                if ([t.tokenTxt caseInsensitiveCompare:f.relationshipName] == NSOrderedSame) {
                    found = TRUE;
                    relField = f;
                }
            }
        }
        if (!found) {
            t.type = TTError;
            t.value = [NSString stringWithFormat:@"There is no polymorphic relationship '%@' on SObject %@", t.tokenTxt, ctx.filter.primary.name];
            return;
        }
    }
    [ctx execWithChildFilters:^(ContextFilters *childFilters) {
        childFilters.restrictCompletionsToType = childFilters.restrictCompletionsToType & (~TTFunc|TTTypeOf);
        Token *t = e.nextObject;
        while (t.type == TTKeyword && [t matches:@"WHEN"]) {
            t = e.nextObject;
            if (t.type == TTSObject) {
                [t.completions addObjectsFromArray:[Completion completions:relField.referenceTo type:TTSObject]];
                if (![relField.referenceTo containsStringIgnoringCase:t.tokenTxt]) {
                    t.type = TTError;
                    t.value = [NSString stringWithFormat:@"Relationship %@ does not reference SObject %@", relField.relationshipName, t.tokenTxt];
                    return;
                }
                childFilters.primary = [self.describer describe:t.tokenTxt];
                t = e.nextObject;
                if (t.type == TTKeyword) t = e.nextObject; // THEN
                while (t.type == TTFieldPath) {
                    [self resolveFieldPath:t ctx:ctx];
                    t = e.nextObject;
                }
            }
        }
        if (t.type == TTKeyword && [t matches:@"ELSE"]) {
            childFilters.primary = [self.describer describe:@"Name"];
            t = e.nextObject;
            while (t.type == TTFieldPath) {
                [self resolveFieldPath:t ctx:ctx];
                t = e.nextObject;
            }
        }
        if (t.type != TTKeyword || ![t matches:@"END"]) {
            t.type = TTError;
            t.value = @"Expecting keyword END";
        }
        t = e.nextObject;
        while (t != nil) {
            t.type = TTError;
            t.value = [NSString stringWithFormat:@"Unexpected token %@", t.tokenTxt];
            t = e.nextObject;
        }
    }];
}

// The first step in the path is optionally the object name, e.g.
// select account.name from account
// It may also be the alias for the object name, e.g.
// select a.name from account a
// It may also be the alias for a relationship specified in the from clause
// e.g. SELECT count() FROM Contact c, c.Account a WHERE a.name = 'MyriadPubs'
// these can be chained, but need to be in dependency order
// e.g.SELECT count() FROM Contact c, c.Account a, a.CreatedBy u WHERE u.alias = 'Sfell'
// but is an error if they're not in the right order
// e.g.SELECT count() FROM Contact c, a.CreatedBy u, c.Account a WHERE u.alias = 'Sfell'
// they can also reference multiple paths
// e.g. SELECT count() FROM Contact c, c.CreatedBy u, c.Account a WHERE u.alias = 'Sfell' and a.Name > 'a'
// or follow multiple relationships in one go
// SELECT count() FROM Contact x, x.Account.CreatedBy u, x.CreatedBy a WHERE u.alias = 'Sfell' and a.alias='Sfell'
//
// Upon return the fieldPath token has had its value replaces with a Tokens* containing the resolved field path.
-(void)resolveFieldPath:(Token*)fieldPath ctx:(Context*)ctx {
    NSAssert([fieldPath.value isKindOfClass:[NSArray class]], @"TTFieldPath should have an array value");
    NSArray *path = (NSArray*)fieldPath.value;
    NSString *firstStep = path[0];
    __block ZKDescribeSObject *curr = ctx.filter.primary;
    __block NSInteger position = fieldPath.loc.location;
    Tokens *resolvedTokens = [Tokens new];
    fieldPath.value = resolvedTokens;

    // this deals with the direct object name
    if ([firstStep caseInsensitiveCompare:ctx.filter.primary.name] == NSOrderedSame) {
        path = [path subarrayWithRange:NSMakeRange(1, path.count-1)];
        Token *tStep = [fieldPath tokenOf:NSMakeRange(position, firstStep.length)];
        tStep.type = TTAlias;
        [self addSObjectAliasCompletions:ctx to:tStep];
        [resolvedTokens addToken:tStep];
        position += firstStep.length + 1;

    } else {
        // We can use the alias map to resolve the alias. resolveFrom populated this from
        // all the related objects in the from clause.
        ZKDescribeSObject *a = ctx.aliases[[CaseInsensitiveStringKey of:firstStep]];
        if (a != nil) {
            curr = a;
            path = [path subarrayWithRange:NSMakeRange(1,path.count-1)];
            Token *tStep = [fieldPath tokenOf:NSMakeRange(position, firstStep.length)];
            tStep.type = TTAlias;
            [self addSObjectAliasCompletions:ctx to:tStep];
            [resolvedTokens addToken:tStep];
            position += firstStep.length + 1;
        }
    }
    if (path.count == 0) {
        // if they've only specified the object name, then that's not valid.
        Token *err = [fieldPath tokenOf:fieldPath.loc];
        err.type = TTError;
        err.value = [NSString stringWithFormat:@"Need to add a field to the SObject %@", ctx.filter.primary.name];
        [self addSObjectAliasCompletions:ctx to:err];
        [resolvedTokens addToken:err];
        return;
    }

    [ctx execWithChildFilters:^(ContextFilters *childFilters) {
        // childFilters is updated at the bottom of the loop after the first item
        for (NSString *step in path) {
            Token *tStep = [fieldPath tokenOf:NSMakeRange(position, step.length)];
            [self addFieldCompletionsFor:curr to:tStep ctx:ctx];
            if ([curr fieldWithName:step] == nil) {
                // see if its a relationship instead
                ZKDescribeField *df = [curr parentRelationshipsByName][[CaseInsensitiveStringKey of:step]];
                if (curr != nil) {
                    if (df == nil) {
                        tStep.type = TTError;
                        tStep.value = [NSString stringWithFormat:@"There is no field or relationship %@ on SObject %@", step, curr.name];
                        [resolvedTokens addToken:tStep];
                        break;
                        
                    } else if (step == path.lastObject) {
                        tStep.type = TTError;
                        tStep.value = [NSString stringWithFormat:@"%@ is a relationship, it should be followed by a field", df.relationshipName];
                        [resolvedTokens addToken:tStep];
                        break;
                   }
                }
                if (df == nil) {
                    break;
                }
                tStep.type = TTRelationship;
                tStep.value = df;
                if (df.namePointing) {
                    // polymorphic rel, valid fields are from Name, not any of the actual related types.
                    curr = [self.describer describe:@"Name"];
                } else {
                    curr = [self.describer describe:df.referenceTo[0]];
                }
            } else {
                // its a field, it better be the last item on the path.
                if (step != path.lastObject) {
                    NSRange stepEnd = NSMakeRange(tStep.loc.location+tStep.loc.length,1);
                    Token *err = [fieldPath tokenOf:stepEnd];
                    err.type = TTError;
                    err.value = [NSString stringWithFormat:@"%@ is a field not a relationship, it should be the last item in the field path", step];
                    [resolvedTokens addToken:err];
                    break;
                }
                tStep.type = TTField;
                ZKDescribeField *df = [curr fieldWithName:step];
                tStep.value = df;
                // if there's a fields completions filter, check tha the field passes that
                if (childFilters.fieldCompletionsFilter != nil) {
                    if (![childFilters.fieldCompletionsFilter evaluateWithObject:df]) {
                        Token *err = [fieldPath tokenOf:tStep.loc];
                        err.type = TTError;
                        err.value = [NSString stringWithFormat:@"Field %@ exists, but is not valid for use here", df.name];
                        [resolvedTokens addToken:err];
                    }
                }
            }
            [resolvedTokens addToken:tStep];
            position += step.length + 1;
            childFilters.restrictCompletionsToType = childFilters.restrictCompletionsToType & (~(TTFunc | TTTypeOf));
        }
    }];
}

-(CompletionCallback)moveSelection:(NSInteger)amount {
    return ^BOOL(ZKTextView *v, id<ZKTextViewCompletion> c) {
        NSRange s = v.selectedRange;
        s.location += amount;
        v.selectedRange = s;
        return TRUE;
    };
}

-(void)addSObjectAliasCompletions:(Context*)ctx to:(Token*)t {
    [t.completions addObject:[Completion txt:ctx.filter.primary.name type:TTAlias]];
    [t.completions addObjectsFromArray:[Completion completions:[ctx.aliases.allKeys valueForKey:@"value"] type:TTAlias]];
}

-(void)addFieldCompletionsFor:(ZKDescribeSObject*)obj to:(Token*)t ctx:(Context*)ctx {
    TokenType allowedTypes = ctx.filter.restrictCompletionsToType;
    if (allowedTypes & (TTField|TTFieldPath)) {
        for (ZKDescribeField *field in obj.fields) {
            if (ctx.filter.fieldCompletionsFilter == nil || [ctx.filter.fieldCompletionsFilter evaluateWithObject:field]) {
                [t.completions addObject:[field completion]];
            }
        }
    }
    if (allowedTypes & (TTRelationship|TTFieldPath)) {
        [t.completions addObjectsFromArray:[obj parentRelCompletions]];
    }
    if (allowedTypes & TTTypeOf) {
        Completion *c = [Completion txt:@"TYPEOF" type:TTTypeOf];
        c.finalInsertionText = @"TYPEOF Relation WHEN ObjectType THEN id END";
        c.onFinalInsert = [self moveSelection:-28];
        [t.completions addObject:c];
    }
    if (((allowedTypes & TTFunc) != 0) && obj != nil) {
        for (SoqlFunction *f in [SoqlFunction functionsFilteredBy:ctx.filter.fnCompletionsFilter]) {
            Completion* cached = [self.fnCompletionsCache for:f onObject:obj];
            if (cached == nil) {
                cached = [f completionOn:obj];
                [self.fnCompletionsCache setCompletion:cached for:f onObject:obj];
            }
            [t.completions addObject:cached];
        }
    }
}

-(BOOL)addSObjectToToken:(Token*)t {
    NSArray<Completion*> *completions = [Completion completions:self.describer.allQueryableSObjects type:TTSObject];
    for (Completion *c in completions) {
        NSImage *objIcon = [self.describer iconForSObject:c.displayText];
        if (objIcon != nil) {
            c.icon = objIcon;
        }
    }
    [t.completions addObjectsFromArray:completions];
    if (![self.describer knownSObject:t.tokenTxt]) {
        t.type = TTError;
        t.value = [NSString stringWithFormat:@"The SObject '%@' does not exist or is inaccessible", t.tokenTxt];
        return FALSE;
    }
    return TRUE;
}

-(Context*)resolveSoslReturning:(Tokens*)tokens  {
    Context *ctx = [Context new];
    ZKDescribeSObject *o = nil;
    for (Token *t in tokens.tokens) {
        if (t.type == TTSObject) {
            [self addSObjectToToken:t];
            o = [self.describer describe:t.tokenTxt];
            ctx.filter.primary = o;
            if ([t.value isKindOfClass:[Tokens class]]) {
                [self resolveTokenList:(Tokens*)t.value ctx:ctx];
            }
        }
    }
    return ctx;
}

-(Context*)resolveFrom:(Tokens*)tokens parentCtx:(Context*)parentCtx {
    __block NSUInteger skipUntil = 0;
    NSInteger idx = [tokens.tokens indexOfObjectPassingTest:^BOOL(Token * _Nonnull t, NSUInteger idx, BOOL * _Nonnull stop) {
        // TODO, this skip shouldn't be needed now that the tokens are moved into a child collection
        if (t.type == TTChildSelect) {
            skipUntil = t.loc.location + t.loc.length;
        }
        return (t.loc.location >= skipUntil) && (t.type == TTSObject);
    }];
    Context *ctx = [Context new];
    ctx.aliases = [AliasMap new];
    if (idx >= tokens.count) {
        return ctx;
    }
    Token *tSObject = tokens.tokens[idx];
    if (parentCtx == nil || parentCtx.filter.containerType == TTSemiJoinSelect) {
        ctx.filter.primary = [self.describer describe:tSObject.tokenTxt];
        if (![self addSObjectToToken:tSObject]) {
            return ctx;
        }
        if (ctx.filter.primary == nil) {
            return ctx; // cant do anymore without the describe.
        }
    } else {
        // for a nested select the from is a child relationship not an object
        [tSObject.completions addObjectsFromArray:[Completion completions:[parentCtx.filter.primary.childRelationshipsByName.allKeys valueForKey:@"value"] type:TTRelationship]];
        ZKChildRelationship * cr = parentCtx.filter.primary.childRelationshipsByName[[CaseInsensitiveStringKey of:tSObject.tokenTxt]];
        if (cr == nil) {
            tSObject.type = TTError;
            tSObject.value = [NSString stringWithFormat:@"The SObject '%@' does not have a child relationship called %@", parentCtx.filter.primary.name, tSObject.tokenTxt];
            return ctx;
        }
        tSObject.type = TTRelationship;
        ctx.filter.primary = [self.describer describe:cr.childSObject];
    }
    // does the primary sobject have an alias?
    if (tokens.count > idx+1) {
        Token *tSObjectAlias = tokens.tokens[idx+1];
        if (tSObjectAlias.type == TTAliasDecl) {
            ctx.aliases[[CaseInsensitiveStringKey of:tSObjectAlias.tokenTxt]] = ctx.filter.primary;
        }
    }
    NSEnumerator<Token*> *e = [[tokens.tokens subarrayWithRange:NSMakeRange(idx, tokens.tokens.count-idx)] objectEnumerator];
    while (true) {
        Token *t = e.nextObject;
        if (t == nil || t.type == TTKeyword) {
            break;
        }
        if (t.type == TTSObjectRelation) {
            NSAssert([t.value isKindOfClass:[NSArray class]], @"TTSObjectRelation should have an array value");
            NSArray *path = (NSArray*)t.value;
            // first path segment can be an alias or a relationship on the primary object.
            CaseInsensitiveStringKey *firstKey = [CaseInsensitiveStringKey of:path[0]];
            ZKDescribeSObject *curr = ctx.aliases[firstKey];
            [t.completions addObjectsFromArray:[Completion completions:[[[curr parentRelationshipsByName] allValues] valueForKey:@"relationshipName"]
                                                                  type:TTSObjectRelation]];
            NSInteger pos = t.loc.location;
            if (curr != nil) {
                path = [path subarrayWithRange:NSMakeRange(1,path.count-1)];
                pos += firstKey.value.length + 1;
            } else {
                curr = ctx.filter.primary;
            }
            for (NSString *step in path) {
                ZKDescribeField *df = [curr parentRelationshipsByName][[CaseInsensitiveStringKey of:step]];
                if (df == nil) {
                    Token *err = [t tokenOf:NSMakeRange(pos, step.length)];
                    err.type = TTError;
                    [err.completions addObjectsFromArray:
                        [Completion completions:[[[curr parentRelationshipsByName] allValues] valueForKey:@"relationshipName"]
                        type:TTSObjectRelation]];
                    err.value = [NSString stringWithFormat:@"There is no relationship %@ on SObject %@", step, curr.name];
                    [tokens addToken:err];
                    curr = nil;
                    break;
                }
                if (df.namePointing) {
                    // polymorphic rel, valid fields are from Name, not any of the actual related types.
                    curr = [self.describer describe:@"Name"];
                } else {
                    curr = [self.describer describe:df.referenceTo[0]];
                }
                pos += step.length + 1;
            }
            // does this rel have an alias (it should otherwise there's not much point)
            t = e.nextObject;
            if (curr != nil && t.type == TTAliasDecl) {
                ctx.aliases[[CaseInsensitiveStringKey of:t.tokenTxt]] = curr;
            }
        }
    }
    return ctx;
}

-(Token*)resolveNamedDateTime:(Token*)token ctx:(Context*)ctx {
    static dispatch_once_t onceToken;
    static NSArray<NSString*> *names;
    static NSArray<NSString*> *namesWithNumber;
    static NSArray<Completion*> *completions;
    dispatch_once(&onceToken, ^{
        names = @[@"YESTERDAY", @"TODAY",@"TOMORROW",@"LAST_WEEK",@"THIS_WEEK",@"NEXT_WEEK",@"LAST_MONTH",
                  @"THIS_MONTH",@"NEXT_MONTH",@"LAST_90_DAYS",@"NEXT_90_DAYS",@"THIS_QUARTER",@"LAST_QUARTER",@"NEXT_QUARTER",
                  @"THIS_YEAR",@"LAST_YEAR",@"NEXT_YEAR",@"THIS_FISCAL_QUARTER",@"LAST_FISCAL_QUARTER",@"NEXT_FISCAL_QUARTER",
                  @"THIS_FISCAL_YEAR",@"LAST_FISCAL_YEAR",@"NEXT_FISCAL_YEAR"];
        names = [names sortedArrayUsingSelector:@selector(compare:)];
        // These are all the ones with a trailing :n, e.g. LAST_N_DAYS:3
        namesWithNumber = @[@"LAST_N_DAYS", @"NEXT_N_DAYS", @"NEXT_N_WEEKS",@"LAST_N_WEEKS",@"NEXT_N_MONTHS",@"LAST_N_MONTHS",
                            @"NEXT_N_QUARTERS",@"LAST_N_QUARTERS",@"NEXT_N_YEARS",@"LAST_N_YEARS",@"NEXT_N_FISCAL_​QUARTERS",
                            @"LAST_N_FISCAL_​QUARTERS",@"NEXT_N_FISCAL_​YEARS",@"LAST_N_FISCAL_​YEARS"];
        namesWithNumber = [namesWithNumber sortedArrayUsingSelector:@selector(compare:)];
        NSMutableArray *cs = [NSMutableArray arrayWithCapacity:names.count + namesWithNumber.count];
        [cs addObjectsFromArray:[Completion completions:names type:TTLiteralNamedDateTime]];
        for (NSString *n in namesWithNumber) {
            [cs addObject:[Completion txt:[NSString stringWithFormat:@"%@:1", n] type:TTLiteralNamedDateTime]];
        }
        completions = [NSArray arrayWithArray:cs];
    });
    [token.completions addObjectsFromArray:completions];
    NSString *val = [token.tokenTxt uppercaseString];
    NSUInteger nameIdx = [names indexOfObject:val
                                    inSortedRange:NSMakeRange(0, names.count)
                                          options:NSBinarySearchingFirstEqual
                                          usingComparator:^NSComparisonResult(id _Nonnull obj1, id _Nonnull obj2) {
        return [obj1 compare:obj2];
    }];
    if (nameIdx != NSNotFound) {
        return nil;
    }
    NSRange colon = [val rangeOfString:@":"];
    if (colon.location != NSNotFound) {
        NSString *name = [val substringToIndex:colon.location];
        NSUInteger nameIdx = [namesWithNumber indexOfObject:name
                                        inSortedRange:NSMakeRange(0, namesWithNumber.count)
                                              options:NSBinarySearchingFirstEqual
                                              usingComparator:^NSComparisonResult(id _Nonnull obj1, id _Nonnull obj2) {
            return [obj1 compare:obj2];
        }];
        if (nameIdx != NSNotFound) {
            BOOL valid = TRUE;
            BOOL visited = FALSE;
            for(NSInteger pos = colon.location+1; pos < val.length; pos++) {
                unichar c = [val characterAtIndex:pos];
                if (!(c >= '0' && c <= '9')) {
                    valid = FALSE;
                    break;
                }
                visited = TRUE;
            }
            if (valid && visited) {
                return nil;
            }
        }
    }
    Token *err = [token tokenOf:token.loc];
    err.type = TTError;
    err.value = [NSString stringWithFormat:@"%@ is not a valid date literal", token.tokenTxt];
    return err;
}

-(void)applyTokens:(Tokens*)tokens {
    ColorizerStyle *style = [ColorizerStyle styles];
    NSTextStorage *txt = self.view.textStorage;
    BOOL toUpper = [[NSUserDefaults standardUserDefaults] boolForKey:PREF_SOQL_UPPERCASE_KEYWORDS];
    for (Token *t in tokens.tokens) {
        if (t.completions.count > 0) {
            [txt addAttribute:KeyCompletions value:t.completions range:t.loc];
        }
        switch (t.type) {
            case TTFieldPath:
                if ([t.value isKindOfClass:[Tokens class]]) {
                    [self applyTokens:(Tokens*)t.value];
                }
                break;
            case TTOperator:
            case TTKeyword:
                if (toUpper) {
                    [txt replaceCharactersInRange:t.loc withString:[t.tokenTxt uppercaseString]];
                }
                [txt addAttributes:style.keyword range:t.loc];
                break;
            case TTAlias:
            case TTAliasDecl:
                [txt addAttributes:style.alias range:t.loc];
                break;
            case TTField:
                [txt addAttributes:style.field range:t.loc];
                break;
            case TTSObjectRelation:
            case TTRelationship:
                [txt addAttributes:style.relationship range:t.loc];
                break;
            case TTSObject:
                [txt addAttributes:style.sobject range:t.loc];
                if ([t.value isKindOfClass:[Tokens class]]) {
                    [self applyTokens:(Tokens*)t.value];
                }
                break;
            case TTFunc:
                [txt addAttributes:style.func range:t.loc];
                [self applyTokens:(Tokens*)t.value];
                break;
            case TTLiteral:
            case TTLiteralList:
            case TTLiteralString:
            case TTLiteralNumber:
            case TTLiteralDate:
            case TTLiteralDateTime:
            case TTLiteralNamedDateTime:
            case TTLiteralBoolean:
            case TTLiteralNull:
            case TTLiteralCurrency:
                [txt addAttributes:style.literal range:t.loc];
                break;
            case TTTypeOf:
            case TTChildSelect:
            case TTSemiJoinSelect:
                [self applyTokens:(Tokens*)t.value];
                break;
            case TTUsingScope:
            case TTDataCategory:
            case TTListViewName:
                [txt addAttributes:style.field range:t.loc];
                break;
            case TTDataCategoryValue:
                [txt addAttributes:style.literal range:t.loc];
                break;
            case TTError:
                    [txt addAttributes:style.underlined range:t.loc];
                if (t.value != nil) {
                    [txt addAttribute:NSToolTipAttributeName value:t.value range:t.loc];
                    [txt addAttribute:NSCursorAttributeName value:NSCursor.pointingHandCursor range:t.loc];
                }
        }
    }
}


// Delegate only.  Allows delegate to modify the list of completions that will be presented for the partial word at the given range.  Returning nil or a zero-length array suppresses completion.  Optionally may specify the index of the initially selected completion; default is 0, and -1 indicates no selection.
-(NSArray<NSString *> *)textView:(NSTextView *)textView completions:(NSArray<NSString *> *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(nullable NSInteger *)index {
    return nil;
}

// Not part of NSTextView delegate, a similar version that ZKTextView calls. It doesn't use the regular delegate one
// because we need to return nil from that to supress the standard completions (via F5)
-(NSArray*)textView:(NSTextView *)textView completionsForPartialWordRange:(NSRange)charRange {
    NSLog(@"textView completions: for range %lu-%lu '%@' textLength:%ld", charRange.location, charRange.length,
          [textView.string substringWithRange:charRange], textView.textStorage.length);

    __block NSArray<NSString *>* completions = nil;
    [textView.textStorage enumerateAttribute:KeyCompletions inRange:charRange options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
        completions = value;
    }];
    if (completions != nil) {
        NSLog(@"found %lu completions", (unsigned long)completions.count);
        return [completions sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];;
    }
    NSLog(@"no completions found at %lu-%lu", charRange.location, charRange.length);
    return nil;
}

@end

@implementation FnCompletionsCache
-(instancetype)init {
    self = [super init];
    self.cache = [NSMutableDictionary dictionaryWithCapacity:[[SoqlFunction all] count]];
    return self;
}
-(void)setCompletion:(Completion*)completion for:(SoqlFunction*)fn onObject:(ZKDescribeSObject*)obj {
    CompletionBySObject *forObj = self.cache[fn.name];
    if (forObj == nil) {
        forObj = [CompletionBySObject dictionaryWithCapacity:128];
        self.cache[fn.name] = forObj;
    }
    forObj[obj.name] = completion;
}

-(Completion*)for:(SoqlFunction*)fn onObject:(ZKDescribeSObject*)obj {
    CompletionBySObject *forObj = self.cache[fn.name];
    return forObj[obj.name];
}

@end


@interface DLDDescriber()
@property (strong,nonatomic) DescribeListDataSource *describes;
@property (strong,nonatomic) NSMutableSet<NSString*>* pendingDescribes;
@property (strong,nonatomic) NSArray<NSString*> *queryableSObjects;
@property (assign,nonatomic) BOOL typeListLoaded;
@end

@implementation DLDDescriber
+(instancetype)describer:(DescribeListDataSource *)describes {
    DLDDescriber *d = [self new];
    d.describes = describes;
    d.pendingDescribes = [NSMutableSet setWithCapacity:2];
    d.typeListLoaded = NO;
    return d;
}

-(ZKDescribeSObject*)describe:(NSString*)obj; {
    if (obj == nil) {
        NSLog(@"DLDDescriber::describe obj is nil");
        return nil;
    }
    if ([self.describes hasDescribe:obj]) {
        return [self.describes cachedDescribe:obj];
    }
    if ([self.describes isTypeDescribable:obj]) {
        [self.describes prioritizeDescribe:obj];
    }
    // note that we don't put this inside the isTypeDescribable block above because
    // there's a period after login where we're trying to color the soql, but the
    // initial describeGlobal hasn't returned yet, and so isTypeDescribable always
    // returns false. Which would lead us to never capturing that we're waiting on
    // this sobject.
    [self.pendingDescribes addObject:obj];
    return nil;
}

-(BOOL)knownSObject:(NSString*)obj {
    return [self.describes isTypeDescribable:obj];
}

-(NSArray<NSString*>*)allQueryableSObjects {
    if (self.queryableSObjects == nil && self.describes.SObjects != nil) {
        self.queryableSObjects = [[self.describes.SObjects filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"queryable=true"]] valueForKey:@"name"];
    }
    return self.queryableSObjects;
}

-(NSImage *)iconForSObject:(NSString *)type {
    return [self.describes iconForType:type];
}

- (void)describe:(nonnull NSString *)sobject failed:(nonnull NSError *)err {
}

- (void)described:(nonnull NSArray<ZKDescribeSObject *> *)sobjects {
    if (self.pendingDescribes.count == 0) return;
    NSMutableArray *arrived = [NSMutableArray array];
    for (NSString *p in self.pendingDescribes) {
        if ([self.describes hasDescribe:p]) {
            [arrived addObject:p];
        }
    }
    for (NSString *p in arrived) {
        [self.pendingDescribes removeObject:p];
    }
    if (!self.typeListLoaded) {
        // this deals with the small window at app startup where we don't have the global describe yet
        // and so typeDescribable returns false, which means we don't prioritze the describe.
        for (NSString *p in self.pendingDescribes) {
            [self.describes prioritizeDescribe:p];
        }
        self.typeListLoaded = YES;
    }
    if (arrived.count == 0) return;
    NSLog(@"Pending describes for %@ have arrived", [arrived componentsJoinedByString:@","]);
    if (self.onNewDescribe != nil) {
        self.onNewDescribe();
    }
}

@end
