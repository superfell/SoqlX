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

typedef NS_ENUM(uint16_t, TokenTy) {
    TTKeyword,
    TTField,
    TTFunc,
    TTNestedSelect,
    TTTypeOf,
    TTSObject,
    TTSObjectRelation,
    TTOperator,
    TTLiteral,
    TTError  // not really a token type, can be applied to any token
};

@interface Token : NSObject
+(instancetype)txt:(NSString *)txt loc:(NSRange)l;
@property (strong,nonatomic) NSString *txt;
@property (assign,nonatomic) TokenTy type;
@property (assign,nonatomic) NSRange loc;
@property (strong,nonatomic) NSObject *value;
@end

@implementation Token
+(instancetype)txt:(NSString *)txt loc:(NSRange)r {
    Token *tkx = [self new];
    tkx.txt = txt;
    tkx.loc = r;
    return tkx;
}
@end

@interface SoqlTokenizer()
@property (strong,nonatomic) NSMutableArray<Token*> *tokens;
@end

@interface SoqlScanner : NSObject {
    NSString *txt;
    NSUInteger pos;
}
+(instancetype)withString:(NSString *)s;
-(Token *)until:(NSCharacterSet*)sep;
-(Token *)nextToken;
-(Token *)peekToken;
-(unichar)peek;
-(void)skipWs;
-(void)skip:(NSUInteger)n;
-(NSUInteger)posn;
-(NSString *)txtOf:(NSRange)r;
-(BOOL)eof;
@end

@implementation SoqlScanner

+(instancetype)withString:(NSString *)s {
    SoqlScanner *c = [SoqlScanner new];
    c->txt = s;
    c->pos = 0;
    return c;
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
    return [self until:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
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

-(NSString *)scanExpr:(SoqlScanner*)sc {
    [sc skipWs];
    Token *lhs = sc.nextToken;
    lhs.type = TTField;
    [self.tokens addObject:lhs];
    [sc skipWs];
    Token *op = sc.nextToken;
    op.type = TTOperator;
    [self.tokens addObject:op];
    [sc skipWs];
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
        [self.tokens addObject:literal];
        [sc skip:1];
    } else if (x >= '0' && x <= '9') {
        Token *literal = [sc nextToken];
        literal.type = TTLiteral;
        [self.tokens addObject:literal];
    } else {
        Token *literal = [sc nextToken];
        literal.type = TTFunc;
        [self.tokens addObject:literal];
    }
    [sc skipWs];
    Token *next = [sc peekToken];
    if ([next.txt caseInsensitiveCompare:@"AND"] == NSOrderedSame || [next.txt caseInsensitiveCompare:@"OR"] == NSOrderedSame) {
        next.type = TTOperator;
        [self.tokens addObject:next];
        [sc skip:next.txt.length];
        return [self scanExpr:sc];
    }
    return nil;
}

-(NSString *)scanWhere:(SoqlScanner*)sc {
    Token *n = [sc peekToken];
    if ([n.txt caseInsensitiveCompare:@"WHERE"] == NSOrderedSame) {
        [sc skip:5];
        n.type = TTKeyword;
        [self.tokens addObject:n];
        return [self scanExpr:sc];
    }
    return sc.eof ? nil : @"Expected WHERE";
}

-(NSString *)scanFrom:(SoqlScanner*)sc {
    [sc skipWs];
    Token *t = [sc nextToken];
    t.type = TTSObject;
    [self.tokens addObject:t];
    [sc skipWs];
    unichar n = [sc peek];
    while (n == ',') {
        Token *rel = [sc nextToken];
        rel.type = TTSObjectRelation;
        [self.tokens addObject:rel];
        [sc skipWs];
        n = [sc peek];
    }
    return [self scanWhere:sc];
}

-(NSString *)scanSelectExprs:(SoqlScanner*)sc {
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
            return @"Expecting closing )";
        }
        [sc skip:1];
    } else {
        Token *t = [sc peekToken];
        if ([t.txt caseInsensitiveCompare:@"TYPEOF"] == NSOrderedSame) {
            [self scanTypeOf:sc];
        } else if ([t.txt containsString:@"."]) {
            t.type = TTField;
            [self.tokens addObject:t];
            [sc skip:t.txt.length];
        } else {
            // field or func
            [sc skip:t.txt.length];
            Token *name = t;
            [sc skipWs];
            if ([name.txt hasSuffix:@"("] || [sc peek] == '(') {
                // func
                Token *rest = [sc until:[NSCharacterSet characterSetWithCharactersInString:@")"]];
                NSRange r = NSMakeRange(name.loc.location, rest.loc.location+rest.loc.length-name.loc.location);
                Token *fn = [Token txt:[sc txtOf:r] loc:r];
                fn.type = TTFunc;
                [sc skip:1];
                [self.tokens addObject:fn];
            } else {
                // field after all
                t.type = TTField;
                [self.tokens addObject:t];
                [sc skip:t.txt.length];
            }
        }
    }
    [sc skipWs];
    if ([sc peek] == ',') {
        [sc skip:1];
        return [self scanSelectExprs:sc];
    } else {
        Token *from = [sc peekToken];
        if ([from.txt caseInsensitiveCompare:@"FROM"] == NSOrderedSame) {
            [sc skip:4];
            from.type = TTKeyword;
            [self.tokens addObject:from];
            return [self scanFrom:sc];
        }
        return @"Expecting , or FROM";
    }
}

-(NSString *)scanSelect:(SoqlScanner*)sc {
    Token *v = [sc nextToken];
    if ([v.txt caseInsensitiveCompare:@"SELECT"] != NSOrderedSame) {
        return @"expecting SELECT";
    }
    v.type = TTKeyword;
    [self.tokens addObject:v];
    return [self scanSelectExprs:sc];
}

-(void)color {
    NSLog(@"starting color");
    self.tokens = [NSMutableArray arrayWithCapacity:10];
    SoqlScanner *sc = [SoqlScanner withString:self.view.textStorage.string];
    [self scanSelect:sc];
    NSTextStorage *txt = self.view.textStorage;
    ColorizerStyle *style = [ColorizerStyle styles];
    NSRange before =  [self.view selectedRange];
    [txt beginEditing];
    for (Token *t in self.tokens) {
        switch (t.type) {
            case TTKeyword:
                [txt replaceCharactersInRange:t.loc withString:[t.txt uppercaseString]];
                [txt addAttributes:style.keyWord range:t.loc];
                break;
            case TTOperator:
                [txt replaceCharactersInRange:t.loc withString:[t.txt uppercaseString]];
            case TTField:
            case TTSObject:
                [txt addAttributes:style.field range:t.loc];
                break;
            case TTFunc:
                [txt addAttributes:style.field range:t.loc];
                break;
            case TTLiteral:
                [txt addAttributes:style.literal range:t.loc];
                break;
            case TTNestedSelect:
            case TTTypeOf:
            case TTSObjectRelation:
            case TTError:
                [txt addAttributes:style.literal range:t.loc];
        }
    }
    [txt endEditing];
    [self.view setSelectedRange:before];
}


// Delegate only.  Allows delegate to modify the list of completions that will be presented for the partial word at the given range.  Returning nil or a zero-length array suppresses completion.  Optionally may specify the index of the initially selected completion; default is 0, and -1 indicates no selection.
- (NSArray<NSString *> *)textView:(NSTextView *)textView completions:(NSArray<NSString *> *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(nullable NSInteger *)index {
    NSLog(@"textView completions: for range %lu-%lu '%@' selectedIndex %ld textLength:%ld", charRange.location, charRange.length,
          [textView.string substringWithRange:charRange], (long)*index, textView.textStorage.length);
//    if (charRange.length==0) {
//        return nil;
//    }
//    NSRange effectiveRange;
//    NSString *txtPrefix = [[textView.string substringWithRange:charRange] lowercaseString];
//    completions c = [textView.textStorage attribute:KeyCompletions atIndex:charRange.location + charRange.length-1 effectiveRange:&effectiveRange];
//    if (c != nil) {
//        NSLog(@"effectiveRange %lu-%lu '%@'", effectiveRange.location, effectiveRange.length, [textView.string substringWithRange:effectiveRange]);
//        *index =-1;
//        NSArray<NSString*>*items = c();
//        return [items filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
//            return [[evaluatedObject lowercaseString] hasPrefix:txtPrefix];
//        }]];
//    } else {
//        NSLog(@"no completions found at %lu-%lu", charRange.location, charRange.length);
//    }
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
