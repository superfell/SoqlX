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

#import "SoqlColorizer.h"
#import <objc/runtime.h>
#import <ZKParser/SoqlParser.h>
#import <ZKParser/Soql.h>
#import "DataSources.h"
#import "CaseInsensitiveStringKey.h"

@interface SoqlColorizer()
@property (strong,nonatomic) SoqlParser *soqlParser;
@end

@interface ColorizerStyle : NSObject

@property (strong) NSColor *fieldColor;
@property (strong) NSColor *keywordColor;
@property (strong) NSColor *literalColor;
@property (strong) NSNumber *underlineStyle;
@property (strong) NSDictionary *underlined;
@property (strong) NSDictionary *noUnderline;

@property (strong) NSDictionary *keyWord;
@property (strong) NSDictionary *field;
@property (strong) NSDictionary *literal;

@end

static ColorizerStyle *style;

typedef ZKDescribeSObject*(^describe)(NSString *sobjectName);

typedef struct {
    From *from;
    ZKDescribeSObject *desc;
    describe describer;
} Context;

@interface Expr (Colorize)
-(void)colorize:(NSTextStorage*)view desc:(Context*)desc;
@end

@interface ZKDescribeSObject (Colorize)
-(NSDictionary<CaseInsensitiveStringKey*,ZKDescribeField*>*)parentRelationshipsByName;
-(NSDictionary<CaseInsensitiveStringKey*,ZKChildRelationship*>*)childRelationshipsByName;
@end
    
@implementation SoqlColorizer

+(void)initialize {
    style = [ColorizerStyle new];
}

-(instancetype)init {
    self = [super init];
    self.soqlParser = [SoqlParser new];
    return self;
}

-(void)color:(NSTextView *)view describes:(DescribeListDataSource *)describes {
    NSTextStorage *soqlTextStorage = view.textStorage;
    NSString *soqlText = soqlTextStorage.string;

    NSError *parseErr = nil;
    SelectQuery *q = [self.soqlParser parse:soqlText error:&parseErr];
    if (parseErr != nil) {
        NSLog(@"parse error: %@", parseErr);
        return;
    }
    describe d = ^ZKDescribeSObject*(NSString *name) {
        if ([describes hasDescribe:name])
            return [describes cachedDescribe:name];
        else if ([describes isTypeDescribable:name]) {
            [describes prioritizeDescribe:name];
        }
        return nil;
    };
    Context ctx = { nil, nil, d };
    [q colorize:soqlTextStorage desc:&ctx];
};
@end

@implementation Expr (Colorize)
-(void)colorize:(NSTextStorage*)view desc:(Context*)ctx {
    NSAssert(false, @"colorize not implemented for type %@", [self class]);
}
@end

@implementation SelectQuery (Colorize)
-(Context)queryContext:(Context*)parentCtx {
    ZKDescribeSObject *d = parentCtx->describer(self.from.sobject.name.val);
    Context c = {self.from, d, parentCtx->describer};
    return c;
}

-(void)colorize:(NSTextStorage*)txt desc:(Context*)ctx {
    Context qCtx = [self queryContext:ctx];
    [txt addAttributes:style.keyWord range:self.loc];
    for (Expr *f in self.selectExprs) {
        [f colorize:txt desc:&qCtx];
    }
    [txt addAttributes:style.field range:self.from.loc];
    for (OrderBy *o in self.orderBy.items) {
        [o.field colorize:txt desc:&qCtx];
    }
    [self.where colorize:txt desc:&qCtx];
}
@end

@implementation NestedSelectQuery (Colorize)
-(Context)queryContext:(Context*)parentCtx {
    NSString *from = self.from.sobject.name.val;
    ZKDescribeSObject *d = parentCtx->describer(from);
    // for nested selected the from may be a relationship from the parent rather than an exact type.
    if (d == nil && parentCtx->desc != nil) {
        ZKChildRelationship *cr = [parentCtx->desc childRelationshipsByName][[CaseInsensitiveStringKey of:from]];
        if (cr != nil) {
            d = parentCtx->describer(cr.childSObject);
        }
    }
    Context c = {self.from, d, parentCtx->describer};
    return c;
}
@end
    
@implementation SelectField (Colorize)
-(void)colorize:(NSTextStorage*)txt desc:(Context*)ctx {
    [txt addAttributes:style.field range:self.loc];
    ZKDescribeSObject *obj = ctx->desc;
    NSArray<PositionedString*> *path = self.name;
    // The first step in the path is optionally the object name, e.g.
    // select account.name from account is valid.
    // It may also be the alias for the object name, e.g.
    // select a.name from account a
    NSString *firstStep = path[0].val;
    if ([firstStep caseInsensitiveCompare:obj.name] == NSOrderedSame
         || [firstStep caseInsensitiveCompare:ctx->from.sobject.alias.val] == NSOrderedSame) {
        path = [path subarrayWithRange:NSMakeRange(1, path.count-1)];
        if (path.count == 0) {
            // if they've only specified the object name, then that's not valid.
            [txt addAttributes:style.underlined range:self.name[0].loc];
        }
    }
    for (PositionedString *f in path) {
        if ([obj fieldWithName:f.val] == nil) {
            // see if its a relationship instead
            ZKDescribeField *df = [obj parentRelationshipsByName][[CaseInsensitiveStringKey of:f.val]];
            if (df == nil || f == self.name.lastObject) {
                [txt addAttributes:style.underlined range:NSUnionRange(f.loc, [self.name lastObject].loc)];
                return;
            }
            if (df.namePointing) {
                // polymorphic rel, valid fields are from Name, not any of the actual related types.
                obj = ctx->describer(@"Name");
            } else {
                obj = ctx->describer(df.referenceTo[0]);
            }
        }
    }
}
@end

@implementation SelectFunc (Colorize)
-(void)colorize:(NSTextStorage*)txt desc:(Context*)ctx {
    for (Expr *e in self.args) {
        [e colorize:txt desc:ctx];
    }
    if (self.alias != nil) {
        [txt addAttributes:style.field range:self.alias.loc];
    }
}
@end

@implementation NotExpr (Colorize)
-(void)colorize:(NSTextStorage*)txt desc:(Context*)ctx {
    [self.expr colorize:txt desc:ctx];
}
@end

@implementation ComparisonExpr (Colorize)
-(void)colorize:(NSTextStorage*)txt desc:(Context*)ctx {
    [self.left colorize:txt desc:ctx];
    [self.right colorize:txt desc:ctx];
}
@end

@implementation OpAndOrExpr (Colorize)
-(void)colorize:(NSTextStorage*)txt desc:(Context*)ctx {
    [self.leftExpr colorize:txt desc:ctx];
    [self.rightExpr colorize:txt desc:ctx];
}
@end

@implementation LiteralValue (Colorize)
-(void)colorize:(NSTextStorage*)txt desc:(Context*)ctx {
    [txt addAttributes:style.literal range:self.loc];
}
@end

@implementation LiteralValueArray (Colorize)
-(void)colorize:(NSTextStorage*)txt desc:(Context*)ctx {
    [txt addAttributes:style.literal range:self.loc];
}
@end

@implementation ColorizerStyle

-(instancetype)init {
    self = [super init];
    self.fieldColor = [NSColor colorNamed:@"soql.field"];
    self.keywordColor = [NSColor colorNamed:@"soql.keyword"];
    self.literalColor = [NSColor colorNamed:@"soql.literal"];
    
    self.underlineStyle = @(NSUnderlineStyleSingle | NSUnderlinePatternDot | NSUnderlineByWord);
    self.underlined = @{
                        NSUnderlineStyleAttributeName: self.underlineStyle,
                        NSUnderlineColorAttributeName: [NSColor redColor],
                        };
    self.noUnderline = @{ NSUnderlineStyleAttributeName: @(NSUnderlineStyleNone) };
    
    self.keyWord = @{ NSForegroundColorAttributeName:self.keywordColor, NSUnderlineStyleAttributeName: @(NSUnderlineStyleNone)};
    self.field =   @{ NSForegroundColorAttributeName:self.fieldColor,   NSUnderlineStyleAttributeName: @(NSUnderlineStyleNone)};
    self.literal = @{ NSForegroundColorAttributeName:self.literalColor, NSUnderlineStyleAttributeName: @(NSUnderlineStyleNone)};
    return self;
}
@end

@implementation ZKDescribeSObject (Colorize)

-(NSDictionary<CaseInsensitiveStringKey*,ZKDescribeField*>*)parentRelationshipsByName {
    NSDictionary<CaseInsensitiveStringKey*,ZKDescribeField*>* r = objc_getAssociatedObject(self, @selector(parentRelationshipsByName));
    if (r == nil) {
        NSMutableDictionary<CaseInsensitiveStringKey*,ZKDescribeField*>* pr = [NSMutableDictionary dictionary];
        for (ZKDescribeField *f in self.fields) {
            if (f.relationshipName.length > 0) {
                [pr setObject:f forKey:[CaseInsensitiveStringKey of:f.relationshipName]];
            }
        }
        r = pr;
        objc_setAssociatedObject(self, @selector(parentRelationshipsByName), r, OBJC_ASSOCIATION_RETAIN);
    }
    return r;
}

-(NSDictionary<CaseInsensitiveStringKey*,ZKChildRelationship*>*)childRelationshipsByName {
    NSDictionary<CaseInsensitiveStringKey*,ZKChildRelationship*>* r = objc_getAssociatedObject(self, @selector(childRelationshipsByName));
    if (r == nil) {
        NSMutableDictionary<CaseInsensitiveStringKey*,ZKChildRelationship*>* cr = [NSMutableDictionary dictionaryWithCapacity:self.childRelationships.count];
        for (ZKChildRelationship *r in self.childRelationships) {
            [cr setObject:r forKey:[CaseInsensitiveStringKey of:r.relationshipName]];
        }
        r = cr;
        objc_setAssociatedObject(self, @selector(childRelationshipsByName), r, OBJC_ASSOCIATION_RETAIN);
    }
    return r;
}

@end
