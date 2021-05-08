//
//  SoqlToken.m
//  SoqlXplorer
//
//  Created by Simon Fell on 4/23/21.
//

#import "SoqlToken.h"
#import "ColorizerStyle.h"

@interface Icons()
@property (strong,nonatomic) NSDictionary<NSNumber*, NSImage*> *icons;
@end

@implementation Icons

static Icons *iconInstance;

+(void)initialize {
    iconInstance = [Icons new];
    ColorizerStyle *style = [ColorizerStyle styles];
    NSSize sz = NSMakeSize(64,64);
    NSImage *lit = [NSImage imageWithSize:sz flipped:NO drawingHandler:[self iconDrawingHandler:@"V" color:style.literalColor]];
    iconInstance.icons = @{
        @(TTField) : [NSImage imageWithSize:sz flipped:NO drawingHandler:[self iconDrawingHandler:@"F" color:style.fieldColor]],
        @(TTSObject) : [NSImage imageWithSize:sz flipped:NO drawingHandler:[self iconDrawingHandler:@"O" color:style.sobjectColor]],
        @(TTRelationship) : [NSImage imageWithSize:NSMakeSize(64, 64) flipped:NO drawingHandler:[self iconDrawingHandler:@"R" color:style.relColor]],
        @(TTOperator) : [NSImage imageWithSize:sz flipped:NO drawingHandler:[self iconDrawingHandler:@"Op" color:style.keywordColor]],
        @(TTKeyword) : [NSImage imageWithSize:sz flipped:NO drawingHandler:[self iconDrawingHandler:@"K" color:style.keywordColor]],
        @(TTTypeOf) : [NSImage imageWithSize:sz flipped:NO drawingHandler:[self iconDrawingHandler:@"T" color:style.keywordColor]],
        @(TTFunc) : [NSImage imageWithSize:sz flipped:NO drawingHandler:[self iconDrawingHandler:@"\xF0\x9D\x91\x93"  color:style.funcColor]],
        @(TTLiteral) : lit,
        @(TTLiteralList) : lit,
        @(TTLiteralString) : lit,
        @(TTLiteralNumber) : lit,
        @(TTLiteralDate) : lit,
        @(TTLiteralDateTime) : lit,
        @(TTLiteralNamedDateTime) : lit,
        @(TTLiteralBoolean) : lit,
        @(TTLiteralNull) : lit,
    };
}

+(BOOL(^)(NSRect))iconDrawingHandler:(NSString*)txt color:(NSColor *)color {
    NSDictionary *txtStyle = @{
        NSForegroundColorAttributeName: [NSColor whiteColor],
        NSFontAttributeName: [NSFont boldSystemFontOfSize:48],
    };
    return ^BOOL(NSRect dstRect) {
        CGContextRef const context = NSGraphicsContext.currentContext.CGContext;
        CGPathRef box = CGPathCreateWithRoundedRect(CGRectInset(dstRect, 4, 4), 8, 8, nil);
        [color setStroke];
        [[color blendedColorWithFraction:0.75 ofColor:[NSColor blackColor]] setFill];
        CGContextAddPath(context, box);
        CGContextSetLineWidth(context, 6);
        CGContextDrawPath(context, kCGPathFillStroke);
        NSSize sz = [txt sizeWithAttributes:txtStyle];
        NSRect txtRect = NSMakeRect((dstRect.size.width-ceil(sz.width))/2, ((dstRect.size.height-ceil(sz.height))/2)+1, ceil(sz.width), ceil(sz.height));
        [txt drawInRect:txtRect withAttributes:txtStyle];
        return YES;
    };
}

+(NSImage*)iconFor:(TokenType)t {
    return iconInstance.icons[@(t)];
}

@end


@implementation Completion
+(NSArray<Completion*>*)completions:(NSArray<NSString*>*)txt type:(TokenType)ty {
    NSMutableArray *r = [NSMutableArray arrayWithCapacity:txt.count];
    for (NSString *t in txt) {
        [r addObject:[Completion txt:t type:ty]];
    }
    return r;
}

+(instancetype)txt:(NSString*)txt type:(TokenType)t {
    return [self display:txt insert:txt finalInsertion:txt type:t];
}

+(instancetype)display:(NSString*)d insert:(NSString*)i finalInsertion:(NSString*)fi type:(TokenType)t {
    Completion *c = [self new];
    c.displayText = d;
    c.nonFinalInsertionText = i;
    c.finalInsertionText = fi;
    c.type = t;
    c.icon = [Icons iconFor:t];
    return c;
}

-(NSString*)description {
    return self.displayText;
}

-(NSComparisonResult)caseInsensitiveCompare:(Completion*)rhs {
    return [self.displayText caseInsensitiveCompare:rhs.displayText];
}

@end

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
