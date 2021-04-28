//
//  SoqlTokenizer.m
//  AppExplorer
//
//  Created by Simon Fell on 4/17/21.
//

#include <mach/mach_time.h>

#import <objc/runtime.h>
#import "SoqlTokenizer.h"
#import "DataSources.h"
#import "CaseInsensitiveStringKey.h"
#import "ColorizerStyle.h"
#import "SoqlToken.h"
#import "SoqlParser.h"
#import "SoqlFunction.h"

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

@interface Context : NSObject
@property (strong,nonatomic) ZKDescribeSObject *primary;
@property (strong,nonatomic) AliasMap *aliases;
@property (assign,nonatomic) TokenType containerType;
@property (strong,nonatomic) NSPredicate *fieldCompletionsFilter;
@property (assign,nonatomic) TokenType restrictCompletionsToType;
@end

@implementation Context
@end

@interface SoqlTokenizer()
@property (strong,nonatomic) Tokens *tokens;
@property (strong,nonatomic) SoqlParser *soqlParser;
@property (strong,nonatomic) NSDictionary<CaseInsensitiveStringKey*,SoqlFunction*> *functions;
@end

@implementation SoqlTokenizer

static NSString *KeyCompletions = @"completions";

-(instancetype)init {
    self = [super init];
    self.soqlParser = [SoqlParser new];
    self.functions = [SoqlFunction all];
    return self;
}

-(void)textDidChange:(NSNotification *)notification {
    [self color];
}

-(void)scanWithParser:(NSString*)input {
    NSError *err = nil;
    self.tokens = [self.soqlParser parse:input error:&err];
    if (err != nil) {
        // TODO setting an error on the insertion point when its at the end of the string is problematic
        Token *t = [Token txt:input loc:NSMakeRange([err.userInfo[@"Position"] integerValue]-1, 0)];
        t.type = TTError;
        [self.tokens addToken:t];
    }
}

-(Tokens*)parseAndResolve:(NSString*)soql {
    [self scanWithParser:soql];
    [self resolveTokens:self.tokens];
    NSLog(@"resolved tokens\n%@\n", self.tokens);
    return self.tokens;
}

-(void)color {
    [self parseAndResolve:self.view.textStorage.string];
    NSTextStorage *txt = self.view.textStorage;
    NSRange before =  [self.view selectedRange];
    [txt beginEditing];
    NSRange all = NSMakeRange(0,txt.length);
    [txt removeAttribute:NSToolTipAttributeName range:all];
    [txt addAttribute:NSForegroundColorAttributeName value:[NSColor whiteColor] range:all];
    [txt removeAttribute:NSUnderlineStyleAttributeName range:all];
    [txt removeAttribute:KeyCompletions range:all];
    [self applyTokens:self.tokens];
    [txt endEditing];
    [self.view setSelectedRange:before];
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
    Context *ctx = [self resolveFrom:tokens parentCtx:parentCtx];
    [self resolveSelectExprs:tokens ctx:ctx];
}

-(void)resolveSelectExprs:(Tokens*)tokens ctx:(Context*)ctx {
    NSMutableArray<Token*> *newTokens = [NSMutableArray arrayWithCapacity:4];
    NSMutableArray<Token*> *delTokens = [NSMutableArray arrayWithCapacity:4];
    [tokens.tokens enumerateObjectsUsingBlock:^(Token * _Nonnull sel, NSUInteger idx, BOOL * _Nonnull stop) {
        [self resolveSelectExpr:sel new:newTokens del:delTokens ctx:ctx];
    }];
    for (Token *t in delTokens) {
        [tokens removeToken:t];
    }
    for (Token *t in newTokens) {
        [tokens addToken:t];
    }
}

-(void)resolveSelectExpr:(Token*)expr new:(NSMutableArray<Token*>*)newTokens del:(NSMutableArray<Token*>*)delTokens ctx:(Context*)ctx {
    switch (expr.type) {
        case TTFieldPath:
            [delTokens addObject:expr];
            [newTokens addObjectsFromArray:[self resolveFieldPath:expr ctx:ctx]];
            break;
        case TTFunc:
            [newTokens addObjectsFromArray:[self resolveFunc:expr ctx:ctx]];
            break;
        case TTTypeOf:
            [newTokens addObjectsFromArray:[self resolveTypeOf:expr ctx:ctx]];
            break;
        case TTChildSelect:
        case TTSemiJoinSelect:
            ctx.containerType = expr.type;
            [self resolveTokens:(Tokens*)expr.value ctx:ctx];
        default:
            break;
    }
}

-(NSArray<Token*>*)resolveFunc:(Token*)f ctx:(Context*)ctx {
    NSMutableArray *newTokens = [NSMutableArray array];
    SoqlFunction *fn = [SoqlFunction all][[CaseInsensitiveStringKey of:f.tokenTxt]];
    if (fn == nil) {
        Token *err = [f tokenOf:f.loc];
        err.type = TTError;
        err.value = [NSString stringWithFormat:@"There is no function named '%@'", f.tokenTxt];
        [newTokens addObject:err];
        [self resolveSelectExprs:(Tokens*)f.value ctx:ctx];
        return newTokens;
    }
    Tokens *argTokens = (Tokens*)f.value;
    if (argTokens.count != fn.args.count) {
        Token *err = [f tokenOf:f.loc];
        err.type = TTError;
        err.value = [NSString stringWithFormat:@"The function %@ should have %ld arguments, but has %ld", f.tokenTxt, fn.args.count, argTokens.count];
        [newTokens addObject:err];
    }
    NSMutableArray *argsNewTokens = [NSMutableArray array];
    NSMutableArray *argsDelTokens = [NSMutableArray array];
    NSEnumerator<SoqlFuncArg*> *fnArgs = fn.args.objectEnumerator;
    NSPredicate *fieldFilter = ctx.fieldCompletionsFilter;
    TokenType completionRestriction = ctx.restrictCompletionsToType;
    for (Token *argToken in argTokens.tokens) {
        SoqlFuncArg *argSpec = fnArgs.nextObject;
        ctx.fieldCompletionsFilter = argSpec.fieldFilter;
        ctx.restrictCompletionsToType = argSpec.type;
        if (argSpec != nil && argSpec.type != argToken.type) {
            Token *err = [argToken tokenOf:argToken.loc];
            err.type = TTError;
            err.value = [NSString stringWithFormat:@"Function argument of unexpected type, should be %@",tokenName(argSpec.type)];
            [argsNewTokens addObject:err];
        }
        [self resolveSelectExpr:argToken new:argsNewTokens del:argsDelTokens ctx:ctx];
    }
    ctx.fieldCompletionsFilter = fieldFilter;
    ctx.restrictCompletionsToType = completionRestriction;
    for (Token *t in argsDelTokens) {
        [argTokens removeToken:t];
    }
    for (Token *t in argsNewTokens) {
        [argTokens addToken:t];
    }
    return newTokens;
}

-(NSArray<Token*>*)resolveTypeOf:(Token*)typeOf ctx:(Context*)ctx {
    if (ctx.primary == nil) {
        return [NSArray array];
    }
    NSAssert([typeOf.value isKindOfClass:[Tokens class]], @"TypeOf token should have an child tokens value");
    Tokens *tokens = (Tokens*) typeOf.value;
    NSEnumerator<Token*> *e = tokens.tokens.objectEnumerator;
    Token *t = e.nextObject;
    if (t.type == TTKeyword) t = e.nextObject;  // TYPEOF
    ZKDescribeField *relField = nil;
    if (t.type == TTRelationship) {
        BOOL found = FALSE;
        for (ZKDescribeField *f in ctx.primary.fields) {
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
            t.value = [NSString stringWithFormat:@"There is no polymorphic relationship '%@' on SObject %@", t.tokenTxt, ctx.primary.name];
            return [NSArray array];
        }
    }
    ZKDescribeSObject *originalPrimary = ctx.primary;
    NSMutableArray<Token*>* newTokens = [NSMutableArray array];
    t = e.nextObject;
    while (t.type == TTKeyword && [t matches:@"WHEN" caseSensitive:NO]) {
        t = e.nextObject;
        if (t.type == TTSObject) {
            [t.completions addObjectsFromArray:[Completion completions:relField.referenceTo type:TTSObject]];
            if (![relField.referenceTo containsStringIgnoringCase:t.tokenTxt]) {
                t.type = TTError;
                t.value = [NSString stringWithFormat:@"%@ is not a reference to %@", relField.name, t.tokenTxt];
                return newTokens;
            }
            ZKDescribeSObject *curr = [self.describer describe:t.tokenTxt];
            t = e.nextObject;
            if (t.type == TTKeyword) t = e.nextObject; // THEN
            ctx.primary = curr;
            while (t.type == TTFieldPath) {
                [newTokens addObjectsFromArray:[self resolveFieldPath:t ctx:ctx]];
                t = e.nextObject;
            }
            ctx.primary = originalPrimary;
        }
    }
    if (t.type == TTKeyword && [t matches:@"ELSE"]) {
        ZKDescribeSObject *curr = [self.describer describe:@"Name"];
        t = e.nextObject;
        ctx.primary = curr;
        while (t.type == TTFieldPath) {
            [newTokens addObjectsFromArray:[self resolveFieldPath:t ctx:ctx]];
            t = e.nextObject;
        }
        ctx.primary = originalPrimary;
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
    return newTokens;
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
-(NSArray<Token*>*)resolveFieldPath:(Token*)fieldPath ctx:(Context*)ctx {
    NSAssert([fieldPath.value isKindOfClass:[NSArray class]], @"TTFieldPath should have an array value");
    NSArray *path = (NSArray*)fieldPath.value;
    NSString *firstStep = path[0];
    ZKDescribeSObject *curr = ctx.primary;
    NSInteger position = fieldPath.loc.location;
    NSMutableArray *newTokens = [NSMutableArray array];

    // this deals with the direct object name
    if ([firstStep caseInsensitiveCompare:ctx.primary.name] == NSOrderedSame) {
        path = [path subarrayWithRange:NSMakeRange(1, path.count-1)];
        Token *tStep = [fieldPath tokenOf:NSMakeRange(position, firstStep.length)];
        tStep.type = TTAlias;
        [self addSObjectAliasCompletions:ctx to:tStep];
        [newTokens addObject:tStep];
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
            [newTokens addObject:tStep];
            position += firstStep.length + 1;
        }
    }
    if (path.count == 0) {
        // if they've only specified the object name, then that's not valid.
        Token *err = [fieldPath tokenOf:fieldPath.loc];
        err.type = TTError;
        err.value = [NSString stringWithFormat:@"Need to add a field to the SObject %@", ctx.primary.name];
        [self addSObjectAliasCompletions:ctx to:err];
        [newTokens addObject:err];
        return newTokens;
    }

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
                    [newTokens addObject:tStep];
                    return newTokens;
                    
                } else if (step == path.lastObject) {
                    tStep.type = TTError;
                    tStep.value = [NSString stringWithFormat:@"%@ is a relationship, it should be followed by a field", df.relationshipName];
                    [newTokens addObject:tStep];
                    return newTokens;
               }
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
                err.value = [NSString stringWithFormat:@"%@ is a field not a relationship, so should be the last item in the field path", step];
                [newTokens addObject:tStep];
                return newTokens;
            }
            tStep.type = TTField;
            tStep.value = [curr fieldWithName:step];
        }
        [newTokens addObject:tStep];
        position += step.length + 1;
    }
    return newTokens;
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
    [t.completions addObject:[Completion txt:ctx.primary.name type:TTAlias]];
    [t.completions addObjectsFromArray:[Completion completions:[ctx.aliases.allKeys valueForKey:@"value"] type:TTAlias]];
}

-(void)addFieldCompletionsFor:(ZKDescribeSObject*)obj to:(Token*)t ctx:(Context*)ctx {
    if (ctx.restrictCompletionsToType == 0 || ctx.restrictCompletionsToType == TTField || ctx.restrictCompletionsToType == TTFieldPath) {
        NSArray *fields = obj.fields;
        if (ctx.fieldCompletionsFilter != nil) {
            fields = [fields filteredArrayUsingPredicate:ctx.fieldCompletionsFilter];
        }
        [t.completions addObjectsFromArray:[Completion completions:[fields valueForKey:@"name"] type:TTField]];
    }
    if (ctx.restrictCompletionsToType == 0 || ctx.restrictCompletionsToType == TTRelationship || ctx.restrictCompletionsToType == TTFieldPath) {
        [t.completions addObjectsFromArray:[Completion
                                            completions:[obj.parentRelationshipsByName.allValues valueForKey:@"relationshipName"]
                                            type:TTRelationship]];
    }
    if (ctx.restrictCompletionsToType == 0 || ctx.restrictCompletionsToType == TTTypeOf) {
        Completion *c = [Completion txt:@"TYPEOF" type:TTTypeOf];
        c.finalInsertionText = @"TYPEOF Relation WHEN ObjectType THEN id END";
        c.onFinalInsert = [self moveSelection:-28];
        [t.completions addObject:c];
    }
    if (ctx.restrictCompletionsToType == 0 || ctx.restrictCompletionsToType == TTFunc) {
        for (SoqlFunction *f in SoqlFunction.all.allValues) {
            [t.completions addObject:[f completionOn:obj]];
        }
    }
}

-(Context*)resolveFrom:(Tokens*)tokens parentCtx:(Context*)parentCtx {
    __block NSUInteger skipUntil = 0;
    NSInteger idx = [tokens.tokens indexOfObjectPassingTest:^BOOL(Token * _Nonnull t, NSUInteger idx, BOOL * _Nonnull stop) {
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
    if (parentCtx == nil || parentCtx.containerType == TTSemiJoinSelect) {
        ctx.primary = [self.describer describe:tSObject.tokenTxt];
        [tSObject.completions addObjectsFromArray:[Completion completions:self.describer.allQueryableSObjects type:TTSObject]];
        if (![self.describer knownSObject:tSObject.tokenTxt]) {
            tSObject.type = TTError;
            tSObject.value = [NSString stringWithFormat:@"The SObject '%@' does not exist or is inaccessible", tSObject.tokenTxt];
            return ctx;
        }
        if (ctx.primary == nil) {
            return ctx; // cant do anymore without the describe.
        }
    } else {
        // for a nested select the from is a child relationship not an object
        [tSObject.completions addObjectsFromArray:[Completion completions:[parentCtx.primary.childRelationshipsByName.allKeys valueForKey:@"value"] type:TTRelationship]];
        ZKChildRelationship * cr = parentCtx.primary.childRelationshipsByName[[CaseInsensitiveStringKey of:tSObject.tokenTxt]];
        if (cr == nil) {
            tSObject.type = TTError;
            tSObject.value = [NSString stringWithFormat:@"The SObject '%@' does not have a child relationship called %@", parentCtx.primary.name, tSObject.tokenTxt];
            return ctx;
        }
        tSObject.type = TTRelationship;
        ctx.primary = [self.describer describe:cr.childSObject];
    }
    // does the primary sobject have an alias?
    if (tokens.count > idx+1) {
        Token *tSObjectAlias = tokens.tokens[idx+1];
        if (tSObjectAlias.type == TTAliasDecl) {
            ctx.aliases[[CaseInsensitiveStringKey of:tSObjectAlias.tokenTxt]] = ctx.primary;
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
                curr = ctx.primary;
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

-(void)applyTokens:(Tokens*)tokens {
    ColorizerStyle *style = [ColorizerStyle styles];
    NSTextStorage *txt = self.view.textStorage;
    for (Token *t in tokens.tokens) {
        if (t.completions.count > 0) {
            [txt addAttribute:KeyCompletions value:t.completions range:t.loc];
        }
        switch (t.type) {
            case TTFieldPath:
                [txt addAttributes:style.field range:t.loc];
                break;
            case TTKeyword:
                [txt replaceCharactersInRange:t.loc withString:[t.tokenTxt uppercaseString]];
                [txt addAttributes:style.keyWord range:t.loc];
                break;
            case TTOperator:
                [txt replaceCharactersInRange:t.loc withString:[t.tokenTxt uppercaseString]];
                [txt addAttributes:style.keyWord range:t.loc];
                break;
            case TTAlias:
            case TTField:
            case TTRelationship:
            case TTSObject:
            case TTSObjectRelation:
            case TTAliasDecl:
                [txt addAttributes:style.field range:t.loc];
                break;
            case TTFunc:
                [txt addAttributes:style.field range:t.loc];
                [self applyTokens:(Tokens*)t.value];
                break;
            case TTLiteral:
            case TTLiteralList:
                [txt addAttributes:style.literal range:t.loc];
                break;
            case TTTypeOf:
            case TTChildSelect:
            case TTSemiJoinSelect:
                [self applyTokens:(Tokens*)t.value];
                break;
            case TTError:
                [txt addAttributes:style.underlined range:t.loc];
                if (t.value != nil) {
                    [txt addAttribute:NSToolTipAttributeName value:t.value range:t.loc];
                    NSLog(@"%lu-%lu %@", t.loc.location, t.loc.length, t.value);
                }
                
                break;
            case TTUsingScope:
            case TTDataCategory:
            case TTDataCategoryValue:
                [txt addAttributes:style.field range:t.loc];
                break;
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

@interface DLDDescriber()
@property (strong,nonatomic) DescribeListDataSource *describes;
@end

@implementation DLDDescriber
+(instancetype)describer:(DescribeListDataSource *)describes {
    DLDDescriber *d = [self new];
    d.describes = describes;
    return d;
}

-(ZKDescribeSObject*)describe:(NSString*)obj; {
    if ([self.describes hasDescribe:obj]) {
        return [self.describes cachedDescribe:obj];
    }
    if ([self.describes isTypeDescribable:obj]) {
        [self.describes prioritizeDescribe:obj];
    }
    return nil;
}

-(BOOL)knownSObject:(NSString*)obj {
    return [self.describes isTypeDescribable:obj];
}

-(NSArray<NSString*>*)allQueryableSObjects {
    return [[self.describes.SObjects filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"queryable=true"]] valueForKey:@"name"];
}

@end
