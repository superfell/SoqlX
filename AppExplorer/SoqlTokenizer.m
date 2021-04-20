//
//  SoqlTokenizer.m
//  AppExplorer
//
//  Created by Simon Fell on 4/17/21.
//

#import "SoqlTokenizer.h"
#import <objc/runtime.h>
#import <ZKParser/SoqlParser.h>
#import <ZKParser/Soql.h>
#import "DataSources.h"
#import "CaseInsensitiveStringKey.h"
#include <mach/mach_time.h>
#import "ColorizerStyle.h"

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
    TTError
};

@interface Token : NSObject
+(instancetype)txt:(NSString *)txt loc:(NSRange)l;
@property (strong,nonatomic) NSString *txt;
@property (assign,nonatomic) TokenType type;
@property (assign,nonatomic) NSRange loc;
@property (strong,nonatomic) NSObject *value;
@property (strong,nonatomic) NSMutableArray<NSString*>* completions;
@end

@implementation Token
+(instancetype)txt:(NSString *)txt loc:(NSRange)r {
    Token *tkx = [self new];
    tkx.txt = txt;
    tkx.loc = r;
    tkx.completions = [NSMutableArray array];
    return tkx;
}
-(BOOL)matches:(NSString *)txt caseSensitive:(BOOL)cs {
    if (cs) {
        return [txt isEqualToString:self.txt];
    }
    return [txt caseInsensitiveCompare:self.txt] == NSOrderedSame;
}
-(NSString *)description {
    return [NSString stringWithFormat:@"%lu-%lu: %hu: %@: completions:%@", self.loc.location, self.loc.length, self.type, self.txt, [self.completions componentsJoinedByString:@", "]];
}
@end

@interface SoqlScanner : NSObject {
    NSString       *txt;
    NSUInteger      pos;
    NSCharacterSet *defSeparator;
}
+(instancetype)withString:(NSString *)s;
-(Token *)until:(NSCharacterSet*)sep;
-(Token *)consume:(NSString *)txt caseSensitive:(BOOL)cs;
-(Token *)consumeChars:(NSCharacterSet *)cs;
-(Token *)nextToken;
-(Token *)peekToken;
-(unichar)peek;
-(void)skipWs;
-(void)skip:(NSUInteger)n;
-(NSUInteger)posn;
-(NSString *)txtOf:(NSRange)r;
-(BOOL)eof;

@property (strong,nonatomic) NSString *error;
@property (assign,nonatomic) NSInteger errorPos;
@end

@implementation SoqlScanner

+(instancetype)withString:(NSString *)s {
    SoqlScanner *c = [SoqlScanner new];
    c->txt = s;
    c->pos = 0;
    c->defSeparator = [NSCharacterSet characterSetWithCharactersInString:@" \r\n\t(,"];
    return c;
}

-(void)setError:(NSString *)err {
    _error = err;
    self.errorPos = pos;
}

-(BOOL)eof {
    return pos >= txt.length;
}

-(NSString *)txtOf:(NSRange)r {
    return [txt substringWithRange:r];
}

-(NSUInteger)posn {
    return pos;
}

-(void)skip:(NSUInteger)n {
    pos += n;
}

-(void)skipWs {
    NSCharacterSet *ws = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    for (; pos < txt.length; pos++) {
        unichar p = [txt characterAtIndex:pos];
        if (![ws characterIsMember:p]) {
            return;
        }
    }
}
-(Token *)peekToken {
    NSUInteger start = pos;
    Token *t = [self nextToken];
    pos = start;
    return t;
}

-(Token *)nextToken {
    return [self until:defSeparator];
}

-(Token *)consume:(NSString *)txt caseSensitive:(BOOL)cs {
    Token *t = [self peekToken];
    if (t.txt.length != txt.length) {
        return nil;
    }
    BOOL match = NO;
    if (cs) {
        match = [t.txt isEqualToString:txt];
    } else {
        match = [t.txt caseInsensitiveCompare:txt] == NSOrderedSame;
    }
    if (match) {
        pos += txt.length;
        return t;
    }
    [self setError:[NSString stringWithFormat:@"Expecting %@", txt]];
    return nil;
}

-(Token *)consumeChars:(NSCharacterSet *)cs {
    NSUInteger start = pos;
    for (; pos < txt.length; pos++) {
        unichar p = [txt characterAtIndex:pos];
        if (![cs characterIsMember:p]) {
            NSRange loc = NSMakeRange(start,pos-start);
            return [Token txt:[txt substringWithRange:loc] loc:loc];
        }
    }
    NSRange loc = NSMakeRange(start, txt.length-start);
    return [Token txt:[txt substringWithRange:loc] loc:loc];
}

-(Token *)until:(NSCharacterSet *)sep {
    NSUInteger start = pos;
    for (; pos < txt.length; pos++) {
        unichar p = [txt characterAtIndex:pos];
        if ([sep characterIsMember:p]) {
            NSRange loc = NSMakeRange(start,pos-start);
            return [Token txt:[txt substringWithRange:loc] loc:loc];
        }
    }
    NSRange loc = NSMakeRange(start, txt.length-start);
    return [Token txt:[txt substringWithRange:loc] loc:loc];
}

-(unichar)peek {
    return [txt characterAtIndex:pos];
}
-(NSString*)description {
    return [txt substringFromIndex:pos];
}
@end

@interface SoqlTokenizer()
@property (strong,nonatomic) NSMutableArray<Token*> *tokens;
@end

@implementation SoqlTokenizer

static NSString *KeyCompletions = @"completions";

-(void)textDidChange:(NSNotification *)notification {
    [self color];
}

-(NSString *)scanTypeOf:(SoqlScanner*)sc {
    // TODO
    return nil;
}

-(void)scanExpr:(SoqlScanner*)sc {
    [sc skipWs];
    if ([sc eof]) {
        return;
    }
    [self scanFieldOrFunc:sc];
    [sc skipWs];
    Token *op = sc.peekToken;
    NSSet *ops = [NSSet setWithArray:@[@">=",@"=",@">",@"<",@"<=",@"!=",@"LIKE",@"IN",@"INCLUDES",@"EXCLUDES"]];
    [op.completions addObjectsFromArray:[ops allObjects]];
    if (![ops containsObject:[op.txt uppercaseString]]) {
        op.type = TTError;
        op.value = [NSString stringWithFormat:@"Expecting one of %@", ops];
        [self.tokens addObject:op];
        [sc skip:op.txt.length];
        return;
    }
    op.type = TTOperator;
    [self.tokens addObject:op];
    [sc skip:op.txt.length];
    [sc skipWs];
    NSArray<NSString*> *valueCompletions = @[@"\'\'", @"NULL", @"TRUE", @"FALSE", @"2020-04-16", @"2020-04-16T12:00:00Z", @"42", @"42.42"];
    unichar x = [sc peek];
    if (x == '(') {
        [sc skip:1];
        [sc skipWs];
        if ([sc.peekToken.txt caseInsensitiveCompare:@"SELECT"] == NSOrderedSame) {
            NSUInteger start = sc.posn;
            NSMutableArray *tokens = self.tokens;
            self.tokens = [NSMutableArray arrayWithCapacity:10];
            [self scanSelect:sc];
            Token *t = [Token txt:[sc txtOf:NSMakeRange(start, sc.posn-start)] loc:NSMakeRange(start, sc.posn-start)];
            t.type = TTNestedSelect;
            t.value = self.tokens;
            self.tokens = tokens;
            [self.tokens addObject:t];
        } else {
            Token *literal = [sc until:[NSCharacterSet characterSetWithCharactersInString:@")"]];
            literal.type = TTLiteral;
            [self.tokens addObject:literal];
        }
    } else if (x == '\'') {
        [sc skip:1];
        Token *literal = [sc until:[NSCharacterSet characterSetWithCharactersInString:@"\'"]];
        literal.type = TTLiteral;
        [literal.completions addObjectsFromArray:valueCompletions];
        [self.tokens addObject:literal];
        [sc skip:1];
    } else if (x >= '0' && x <= '9') {
        Token *literal = [sc nextToken];
        literal.type = TTLiteral;
        [literal.completions addObjectsFromArray:valueCompletions];

        [self.tokens addObject:literal];
    } else {
        [self scanFieldOrFunc:sc];
    }
    [sc skipWs];
    Token *next = [sc peekToken];
    if ([next.txt caseInsensitiveCompare:@"AND"] == NSOrderedSame || [next.txt caseInsensitiveCompare:@"OR"] == NSOrderedSame) {
        next.type = TTOperator;
        [next.completions addObjectsFromArray:@[@"AND",@"OR"]];
        [self.tokens addObject:next];
        [sc skip:next.txt.length];
        [self scanExpr:sc];
    }
}

-(void)scanWhere:(SoqlScanner*)sc {
    Token *n = [sc peekToken];
    if ([n.txt caseInsensitiveCompare:@"WHERE"] == NSOrderedSame) {
        [sc skip:5];
        n.type = TTKeyword;
        [self.tokens addObject:n];
        [self scanExpr:sc];
    }
    // [self scan order by] etc
}

-(void)scanFrom:(SoqlScanner*)sc {
    [sc skipWs];
    Token *t = [sc nextToken];
    t.type = TTSObject;
    [self.tokens addObject:t];
    [sc skipWs];
    unichar n = [sc peek];
    while (n == ',') {
        [sc skip:1];
        [sc skipWs];
        Token *rel = [sc nextToken];
        rel.type = TTSObjectRelation;
        [self.tokens addObject:rel];
        [sc skipWs];
        n = [sc peek];
    }
    [self scanWhere:sc];
}

-(void)scanFieldOrFunc:(SoqlScanner*)sc {
    Token *t = [sc peekToken];
    if ([t.txt containsString:@"."]) {
        t.type = TTFieldPath;
        [self.tokens addObject:t];
        [sc skip:t.txt.length];
    } else {
        // field or func
        [sc skip:t.txt.length];
        [sc skipWs];
        if ([sc peek] == '(') {
            // func
            Token *name = t;
            Token *rest = [sc until:[NSCharacterSet characterSetWithCharactersInString:@")"]];
            // TODO, this should be separate tokens for the args
            NSRange r = NSUnionRange(name.loc,rest.loc);
            Token *fn = [Token txt:[sc txtOf:r] loc:r];
            fn.type = TTFunc;
            [sc skip:1];
            [self.tokens addObject:fn];
        } else {
            // field after all
            t.type = TTFieldPath;
            [self.tokens addObject:t];
        }
    }
}

-(void)scanSelectExprs:(SoqlScanner*)sc {
    [sc skipWs];
    unichar n = [sc peek];
    if (n == '(') {
        NSUInteger start = sc.posn;
        NSMutableArray<Token*> *currentTokens = self.tokens;
        self.tokens = [NSMutableArray arrayWithCapacity:10];
        [sc skip:1];
        [self scanSelect:sc];
        [sc skipWs];
        NSRange selectLoc = NSMakeRange(start,sc.posn+1);
        Token *select = [Token txt:[sc txtOf:selectLoc] loc:selectLoc];
        select.type = TTNestedSelect;
        select.value = self.tokens;
        self.tokens = currentTokens;
        [self.tokens addObject:select];
        unichar end = [sc peek];
        if (end != ')') {
            Token *err = [sc nextToken];
            err.type = TTError;
            err.value = @"Expecting closing )";
            [err.completions addObject:@")"];
            [self.tokens addObject:err];
            return;
        }
        [sc skip:1];
    } else {
        Token *t = [sc peekToken];
        if ([t.txt caseInsensitiveCompare:@"TYPEOF"] == NSOrderedSame) {
            [self scanTypeOf:sc];
        } else {
            [self scanFieldOrFunc:sc];
        }
    }
    [sc skipWs];
    if ([sc peek] == ',') {
        [sc skip:1];
        [self scanSelectExprs:sc];
    } else {
        Token *from = [sc nextToken];
        if ([from matches:@"FROM" caseSensitive:NO]) {
            from.type = TTKeyword;
            [self.tokens addObject:from];
            [self scanFrom:sc];
        } else {
            from.type = TTError;
            [from.completions addObject:@"FROM"];
            from.value = @"expecting FROM";
            [self.tokens addObject:from];
        }
    }
}

-(void)scanSelect:(SoqlScanner*)sc {
    [sc skipWs];
    Token *t = [sc nextToken];
    if ([t matches:@"SELECT" caseSensitive:NO]) {
        t.type = TTKeyword;
        [self.tokens addObject:t];
        [self scanSelectExprs:sc];
    } else {
        t.type = TTError;
        t.value = @"Expected SELECT";
        [t.completions addObject:@"SELECT"];
        [self.tokens addObject:t];
    }
}

-(void)color {
    NSLog(@"starting color");
    self.tokens = [NSMutableArray arrayWithCapacity:10];
    SoqlScanner *sc = [SoqlScanner withString:self.view.textStorage.string];
    [self scanSelect:sc];
    
    NSLog(@"parsed tokens\n%@", self.tokens);
    [self resolveTokens:self.tokens];
    NSLog(@"resolved tokens\n%@", self.tokens);
    NSTextStorage *txt = self.view.textStorage;
    NSRange before =  [self.view selectedRange];
    [txt beginEditing];
    [self applyTokens:self.tokens];
    [txt endEditing];
    [self.view setSelectedRange:before];
}

-(void)resolveTokens:(NSMutableArray<Token*>*)tokens {
    // This is the 2nd pass that deals with resolving field/object/rel/alias/func tokens
    Token *tSObject;
    for (int i = 0; i < tokens.count; i++) {
        if (tokens[i].type == TTSObject) {
            tSObject = tokens[i];
            // TODO, deal with aliases, relationships etc.s
            break;
        }
    }
    [tSObject.completions addObjectsFromArray:self.allSObjects];
    if (![self knownSObject:tSObject.txt]) {
        Token *err = [Token txt:tSObject.txt loc:tSObject.loc];
        err.type = TTError;
        err.value = [NSString stringWithFormat:@"The SObject '%@' does not exist or is inaccessible", tSObject.txt];
        [tokens addObject:err];
        return;
    }
    NSMutableArray<Token*> *newTokens = [NSMutableArray arrayWithCapacity:4];
    ZKDescribeSObject *desc = [self describe:tSObject.txt];
    tSObject.value = desc;
    for (Token *sel in tokens) {
        if (sel.type == TTFieldPath) {
            NSArray<NSString*>* path = [sel.txt componentsSeparatedByString:@"."];
            NSInteger pos = sel.loc.location;
            ZKDescribeSObject *currentSObject = desc;
            for (NSString *step in path) {
                Token *tStep = [Token txt:step loc:NSMakeRange(pos, step.length)];
                [tStep.completions addObjectsFromArray:[currentSObject valueForKeyPath:@"fields.name"]];
                [tStep.completions addObjectsFromArray:[[[currentSObject parentRelationshipsByName] allValues] valueForKey:@"relationshipName"]];
                ZKDescribeField *f = [currentSObject fieldWithName:step];
                if (f == nil) {
                    ZKDescribeField *rel = [currentSObject parentRelationshipsByName][[CaseInsensitiveStringKey of:step]];
                    if (rel == nil) {
                        tStep.type = TTError;
                        tStep.value = [NSString stringWithFormat:@"The SObject %@ doesn't contain a field or relationship called %@", desc.name, step];
                    } else {
                        tStep.type = TTRelationship;
                        tStep.value = rel;
                        if (rel.namePointing) {
                            currentSObject = [self describe:@"Name"];
                        } else {
                            currentSObject = [self describe:rel.referenceTo[0]];
                        }
                    }
                } else {
                    tStep.type = TTField;
                    tStep.value = f;
                }
                [newTokens addObject:tStep];
                pos += tStep.loc.length + 1;
           }
        } else if (sel.type == TTFunc) {
            
        } else if (sel.type == TTSObject) {
            break;
        }
    }
    [tokens addObjectsFromArray:newTokens];
}

-(void)applyTokens:(NSArray<Token*>*)tokens {
    ColorizerStyle *style = [ColorizerStyle styles];
    NSTextStorage *txt = self.view.textStorage;
    for (Token *t in tokens) {
        if (t.completions.count > 0) {
            [txt addAttribute:KeyCompletions value:t.completions range:t.loc];
        }
        switch (t.type) {
            case TTFieldPath:
                break;
            case TTKeyword:
                [txt replaceCharactersInRange:t.loc withString:[t.txt uppercaseString]];
                [txt addAttributes:style.keyWord range:t.loc];
                break;
            case TTOperator:
                [txt replaceCharactersInRange:t.loc withString:[t.txt uppercaseString]];
                [txt addAttributes:style.keyWord range:t.loc];
                break;
            case TTAlias:
            case TTTypeOf:
            case TTField:
            case TTRelationship:
            case TTSObject:
            case TTSObjectRelation:
            case TTAliasDecl:
                [txt addAttributes:style.field range:t.loc];
                break;
            case TTFunc:
                [txt addAttributes:style.field range:t.loc];
                break;
            case TTLiteral:
            case TTLiteralList:
                [txt addAttributes:style.literal range:t.loc];
                break;
            case TTNestedSelect:
                [self applyTokens:(NSArray<Token*>*)t.value];
                break;
            case TTError:
                [txt addAttributes:style.underlined range:t.loc];
                break;
        }
    }
}


// Delegate only.  Allows delegate to modify the list of completions that will be presented for the partial word at the given range.  Returning nil or a zero-length array suppresses completion.  Optionally may specify the index of the initially selected completion; default is 0, and -1 indicates no selection.
- (NSArray<NSString *> *)textView:(NSTextView *)textView completions:(NSArray<NSString *> *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(nullable NSInteger *)index {
    NSLog(@"textView completions: for range %lu-%lu '%@' selectedIndex %ld textLength:%ld", charRange.location, charRange.length,
          [textView.string substringWithRange:charRange], (long)*index, textView.textStorage.length);

    NSString *txtPrefix = [[textView.string substringWithRange:charRange] lowercaseString];
    __block NSArray<NSString *>* completions = nil;
    [textView.textStorage enumerateAttribute:KeyCompletions inRange:charRange options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
        completions = value;
    }];
    if (completions != nil) {
        *index =-1;
        NSLog(@"found %lu completions", (unsigned long)completions.count);
        NSMutableArray *withPrefix = [NSMutableArray arrayWithCapacity:completions.count];
        NSMutableArray *withoutPrefix = [NSMutableArray arrayWithCapacity:completions.count];
        for (NSString *c in completions) {
            if ((c.length >= txtPrefix.length) && ([[c substringToIndex:txtPrefix.length] caseInsensitiveCompare:txtPrefix] == NSOrderedSame)) {
                [withPrefix addObject:c];
            } else {
                [withoutPrefix addObject:c];
            }
        }
        [withPrefix sortUsingSelector:@selector(caseInsensitiveCompare:)];
        [withoutPrefix sortUsingSelector:@selector(caseInsensitiveCompare:)];
        [withPrefix addObjectsFromArray:withoutPrefix];
        return withPrefix;
    } else {
        NSLog(@"no completions found at %lu-%lu", charRange.location, charRange.length);
    }
    return nil;
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

-(NSArray<NSString*>*)allSObjects {
    return [self.describes.SObjects valueForKey:@"name"];
}


@end
