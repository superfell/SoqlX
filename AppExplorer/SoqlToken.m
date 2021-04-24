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
    iconInstance.icons = @{
        @(TTField) : [NSImage imageWithSize:sz flipped:NO drawingHandler:[self iconDrawingHandler:@"F" color:style.fieldColor]],
        @(TTSObject) : [NSImage imageWithSize:sz flipped:NO drawingHandler:[self iconDrawingHandler:@"O" color:style.fieldColor]],
        @(TTRelationship) : [NSImage imageWithSize:NSMakeSize(64, 64) flipped:NO drawingHandler:[self iconDrawingHandler:@"R" color:style.literalColor]],
        @(TTLiteral) : [NSImage imageWithSize:sz flipped:NO drawingHandler:[self iconDrawingHandler:@"V" color:style.literalColor]],
        @(TTOperator) : [NSImage imageWithSize:sz flipped:NO drawingHandler:[self iconDrawingHandler:@"Op" color:style.keywordColor]],
        @(TTKeyword) : [NSImage imageWithSize:sz flipped:NO drawingHandler:[self iconDrawingHandler:@"K" color:style.keywordColor]],
    };
}

+(BOOL(^)(NSRect))iconDrawingHandler:(NSString*)txt color:(NSColor *)color {
    NSDictionary *txtStyle = @{
        NSForegroundColorAttributeName: [NSColor whiteColor],
        NSFontAttributeName: [NSFont boldSystemFontOfSize:48],
    };
    return ^BOOL(NSRect dstRect) {
        CGContextRef const context = NSGraphicsContext.currentContext.graphicsPort;
        CGPathRef box = CGPathCreateWithRoundedRect(CGRectInset(dstRect, 4, 4), 8, 8, nil);
        [color setStroke];
        [[color blendedColorWithFraction:0.75 ofColor:[NSColor blackColor]] setFill];
        CGContextAddPath(context, box);
        CGContextSetLineWidth(context, 6);
        CGContextDrawPath(context, kCGPathFillStroke);
        NSSize sz = [txt sizeWithAttributes:txtStyle];
        NSRect txtRect = NSMakeRect((dstRect.size.width-sz.width)/2, ((dstRect.size.height-sz.height)/2)+1, sz.width, sz.height);
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
    return [self display:txt insert:txt type:t];
}

+(instancetype)display:(NSString*)d insert:(NSString*)i type:(TokenType)t {
    Completion *c = [self new];
    c.displayText = d;
    c.insertionText = i;
    c.type = t;
    return c;
}
-(NSString*)description {
    return self.displayText;
}
-(NSComparisonResult)caseInsensitiveCompare:(Completion*)rhs {
    return [self.displayText caseInsensitiveCompare:rhs.displayText];
}

static NSMutableArray *icons;

-(NSImage*)icon {
    return [Icons iconFor:self.type];
}
@end



@implementation Token
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

-(NSString *)description {
    return [NSString stringWithFormat:@"%4lu-%-4lu: %@ %@ completions %lu", self.loc.location, self.loc.length,
            [self.typeName stringByPaddingToLength:9 withString:@" " startingAtIndex:0],
            [self.tokenTxt stringByPaddingToLength:25 withString:@" " startingAtIndex:0], (unsigned long)self.completions.count];
}

-(NSString*)typeName {
    switch (self.type) {
        case TTKeyword: return @"Keyword";
        case TTFieldPath: return @"FldPath";
        case TTAlias: return @"Aias";
        case TTRelationship: return @"Rel";
        case TTField: return @"Field";
        case TTFunc: return @"Func";
        case TTNestedSelect: return @"NSelect";
        case TTTypeOf: return @"TypeOf";
        case TTSObject: return @"SObject";
        case TTAliasDecl: return @"AliasDecl";
        case TTSObjectRelation: return @"RelObj";
        case TTOperator: return @"Op";
        case TTLiteral: return @"Lit";
        case TTLiteralList: return @"LitList";
        case TTUsingScope: return @"Scope";
        case TTDataCategory: return @"Cat";
        case TTDataCategoryValue: return @"CatVal";
        case TTError: return @"Error";
    }
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

-(NSArray<Token*>*) tokens {
    return self.items;
}

-(void)addToken:(Token*)t {
    NSRange searchRange = NSMakeRange(0, self.items.count);
    NSUInteger findIndex = [self.items indexOfObject:t
                                        inSortedRange:searchRange
                                              options:NSBinarySearchingInsertionIndex | NSBinarySearchingFirstEqual
                                      usingComparator:^(id obj1, id obj2) {
        Token *a = obj1;
        Token *b = obj2;
        if (a.loc.location == b.loc.location) {
            if (a.loc.length > b.loc.length) {
                return NSOrderedDescending;
            } else if (a.loc.length < b.loc.length) {
                return NSOrderedAscending;
            }
            return NSOrderedSame;
        }
        if (a.loc.location > b.loc.location) {
            return NSOrderedDescending;
        }
        return NSOrderedAscending;
    }];
    [self.items insertObject:t atIndex:findIndex];
}

-(void)removeToken:(Token*)t {
    [self.items removeObject:t];
}

@end
