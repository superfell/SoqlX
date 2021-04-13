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

typedef NSMutableDictionary<CaseInsensitiveStringKey*,ZKDescribeSObject*> AliasMap;

typedef struct {
//    From                *from;      // this can probably go away one aliases is done fully.
    ZKDescribeSObject   *desc;      // the describe of the driving/primary object for the current query.
    AliasMap            *aliases;   // map of alias to the object describe.
    describer           describer;  // a function to get describe results.
} Context;

@interface Expr (Colorize)
-(void)enumerateTokens:(Context*)ctx block:(tokenCallback)b;
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
    describer d = ^ZKDescribeSObject*(NSString *name) {
        if ([describes hasDescribe:name]) {
            return [describes cachedDescribe:name];
        }
        if ([describes isTypeDescribable:name]) {
            [describes prioritizeDescribe:name];
        }
        return nil;
    };
    NSTextStorage *txt = view.textStorage;
    tokenCallback color = ^void(SoqlTokenType t, NSRange loc) {
        switch (t) {
            case TKeyword:
                [txt addAttributes:style.keyWord range:loc];
                break;
            case TField:
                [txt addAttributes:style.field range:loc];
                break;
            case TFunc:
                [txt addAttributes:style.field range:loc];
                break;
            case TLiteral:
                [txt addAttributes:style.literal range:loc];
                break;
            case TError:
                [txt addAttributes:style.underlined range:loc];
                break;
        }
    };
    [self enumerateTokens:txt.string describes:d block:color];
};

-(void)enumerateTokens:(NSString *)soql describes:(describer)d block:(tokenCallback)cb {
    NSError *parseErr = nil;
    SelectQuery *q = [self.soqlParser parse:soql error:&parseErr];
    if (parseErr != nil) {
        NSLog(@"parse error: %@", parseErr);
        return;
    }
    Context ctx = { nil, nil, d };
    [q enumerateTokens:&ctx block:cb];
}

@end

@implementation Expr (Colorize)
-(void)enumerateTokens:(Context*)ctx block:(tokenCallback)b {
    NSAssert(false, @"enumerateTokens not implemented for type %@", [self class]);
}
@end

@implementation SelectQuery (Colorize)
-(Context)queryContext:(Context*)parentCtx {
    ZKDescribeSObject *d = parentCtx->describer(self.from.sobject.name.val);
    Context c = {d, nil, parentCtx->describer};
    return c;
}

-(void)enumerateFrom:(Context *)ctx block:(tokenCallback)cb {
    cb(TField, self.from.sobject.loc);
    if (ctx->desc == nil) {
        cb(TError, self.from.sobject.name.loc);
    }
    AliasMap *aliases = nil;
    if (self.from.sobject.alias.length > 0 || self.from.relatedObjects.count > 0) {
        aliases = [AliasMap dictionaryWithCapacity:self.from.relatedObjects.count + 1];
    }
    if (self.from.sobject.alias.length > 0 && ctx->desc != nil) {
        aliases[[CaseInsensitiveStringKey of:self.from.sobject.alias.val]] = ctx->desc;
    }
    // TODO, this has a large overlap with the code below, and this chunk should probably be done once
    // based on a visit to the From, rather than doing it with every potential alias reference.
    for (SelectField *related in self.from.relatedObjects) {
        cb(TField, related.loc);
        // first path segment can be an alias or a relationship on the primary object.
        CaseInsensitiveStringKey *firstKey = [CaseInsensitiveStringKey of:related.name[0].val];
        NSArray<PositionedString*> *path = related.name;
        ZKDescribeSObject *curr = aliases[firstKey];
        if (curr != nil) {
            path = [path subarrayWithRange:NSMakeRange(1,path.count-1)];
        } else {
            curr = ctx->desc;
        }
        for (PositionedString *step in path) {
            ZKDescribeField *df = [curr parentRelationshipsByName][[CaseInsensitiveStringKey of:step.val]];
            if (df == nil) {
                cb(TError, NSUnionRange(step.loc, related.name.lastObject.loc));
                curr = nil;
                break;
            }
            if (df.namePointing) {
                // polymorphic rel, valid fields are from Name, not any of the actual related types.
                curr = ctx->describer(@"Name");
            } else {
                curr = ctx->describer(df.referenceTo[0]);
            }
        }
        if (curr != nil) {
            aliases[[CaseInsensitiveStringKey of:related.alias.val]] = curr;
        }
    }
    ctx->aliases = aliases;
}

-(void)enumerateTokens:(Context*)ctx block:(tokenCallback)cb {
    cb(TKeyword, self.loc);
    Context qCtx = [self queryContext:ctx];
    [self enumerateFrom:&qCtx block:cb];
    for (Expr *f in self.selectExprs) {
        [f enumerateTokens:&qCtx block:cb];
    }
    [self.where enumerateTokens:&qCtx block:cb];
    for (OrderBy *o in self.orderBy.items) {
        [o.field enumerateTokens:&qCtx block:cb];
    }
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
    Context c = {d, nil, parentCtx->describer};
    return c;
}
@end
    
@implementation SelectField (Colorize)
-(void)enumerateTokens:(Context*)ctx block:(tokenCallback)cb {
    cb(TField, self.loc);
    
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
    
    ZKDescribeSObject *obj = ctx->desc;
    NSArray<PositionedString*> *path = self.name;
    NSString *firstStep = path[0].val;
    // this deals with the direct object name
    if ([firstStep caseInsensitiveCompare:obj.name] == NSOrderedSame) {
        path = [path subarrayWithRange:NSMakeRange(1, path.count-1)];
        if (path.count == 0) {
            // if they've only specified the object name, then that's not valid.
            cb(TError, self.name[0].loc);
        }
    } else {
        // We can use the alias map to resolve the alias. enumeratorFrom populated this from all the related objects in
        // the from clause.
        ZKDescribeSObject *a = ctx->aliases[[CaseInsensitiveStringKey of:firstStep]];
        if (a != nil) {
            obj = a;
            path = [path subarrayWithRange:NSMakeRange(1,path.count-1)];
        }
    }
    for (PositionedString *f in path) {
        if ([obj fieldWithName:f.val] == nil) {
            // see if its a relationship instead
            ZKDescribeField *df = [obj parentRelationshipsByName][[CaseInsensitiveStringKey of:f.val]];
            if (df == nil || f == self.name.lastObject) {
                cb(TError, NSUnionRange(f.loc, [self.name lastObject].loc));
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
-(void)enumerateTokens:(Context*)ctx block:(tokenCallback)cb {
    cb(TFunc, self.name.loc);
    for (Expr *e in self.args) {
        [e enumerateTokens:ctx block:cb];
    }
    if (self.alias != nil) {
        cb(TField, self.alias.loc);
    }
}
@end

@implementation NotExpr (Colorize)
-(void)enumerateTokens:(Context*)ctx block:(tokenCallback)cb {
    [self.expr enumerateTokens:ctx block:cb];
}
@end

@implementation ComparisonExpr (Colorize)
-(void)enumerateTokens:(Context*)ctx block:(tokenCallback)cb {
    [self.left enumerateTokens:ctx block:cb];
    [self.right enumerateTokens:ctx block:cb];
}
@end

@implementation OpAndOrExpr (Colorize)
-(void)enumerateTokens:(Context*)ctx block:(tokenCallback)cb {
    [self.leftExpr enumerateTokens:ctx block:cb];
    [self.rightExpr enumerateTokens:ctx block:cb];
}
@end

@implementation LiteralValue (Colorize)
-(void)enumerateTokens:(Context*)ctx block:(tokenCallback)cb {
    cb(TLiteral, self.loc);
}
@end

@implementation LiteralValueArray (Colorize)
-(void)enumerateTokens:(Context*)ctx block:(tokenCallback)cb {
    cb(TLiteral, self.loc);
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
    
    // TODO, why is colorNamed:@ returning nil in unit tests?
    if (self.keywordColor != nil) {
        self.keyWord = @{ NSForegroundColorAttributeName:self.keywordColor, NSUnderlineStyleAttributeName: @(NSUnderlineStyleNone)};
        self.field =   @{ NSForegroundColorAttributeName:self.fieldColor,   NSUnderlineStyleAttributeName: @(NSUnderlineStyleNone)};
        self.literal = @{ NSForegroundColorAttributeName:self.literalColor, NSUnderlineStyleAttributeName: @(NSUnderlineStyleNone)};
    }
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
