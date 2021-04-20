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
#include <mach/mach_time.h>
#import "ColorizerStyle.h"

@interface SoqlColorizer()
@property (strong,nonatomic) SoqlParser *soqlParser;
@end



typedef NSMutableDictionary<CaseInsensitiveStringKey*,ZKDescribeSObject*> AliasMap;

typedef struct {
    ZKDescribeSObject   *desc;      // the describe of the driving/primary object for the current query.
    AliasMap            *aliases;   // map of alias to the object describe.
    NSObject<Describer> *describer;  // a function to get describe results.
} Context;

@interface Expr (Colorize)
-(void)enumerateTokens:(Context*)ctx block:(tokenCallback)b;
@end

static double ticksToMillis = 0;
NSString *KeyCompletions = @"ZKCompletions";
static ColorizerStyle *style;

@implementation SoqlColorizer

+(void)initialize {
    style = [ColorizerStyle styles];
    
    // The first time we get here, ask the system
    // how to convert mach time units to nanoseconds
    mach_timebase_info_data_t timebase;
    // to be completely pedantic, check the return code of this next call.
    mach_timebase_info(&timebase);
    ticksToMillis = (double)timebase.numer / timebase.denom / 1000000;
}

-(instancetype)init {
    self = [super init];
    self.soqlParser = [SoqlParser new];
    return self;
}

-(void)textDidChange:(NSNotification *)notification {
    [self color];
}

// Delegate only.
- (BOOL)textView:(NSTextView *)textView clickedOnLink:(id)link atIndex:(NSUInteger)charIndex {
    NSLog(@"clickedOnLink: %@ at %lu", link, charIndex);
    return TRUE;
}

// Delegate only.
- (void)textView:(NSTextView *)textView clickedOnCell:(id <NSTextAttachmentCell>)cell inRect:(NSRect)cellFrame atIndex:(NSUInteger)charIndex {
    NSLog(@"clickedOnCell");
}

// Delegate only.
- (void)textView:(NSTextView *)textView doubleClickedOnCell:(id <NSTextAttachmentCell>)cell inRect:(NSRect)cellFrame atIndex:(NSUInteger)charIndex {
    NSLog(@"Double clickedOnCell");
}

- (NSMenu *)textView:(NSTextView *)view
                menu:(NSMenu *)menu
            forEvent:(NSEvent *)event
             atIndex:(NSUInteger)charIndex {
    NSLog(@"textViewMenu forEvent %@ atIndex %lu", event, charIndex);
    [menu insertItemWithTitle:@"Show in Sidebar" action:@selector(highlightItemInSideBar:) keyEquivalent:@"" atIndex:0];
    return menu;
}

// Delegate only.  Allows delegate to modify the list of completions that will be presented for the partial word at the given range.  Returning nil or a zero-length array suppresses completion.  Optionally may specify the index of the initially selected completion; default is 0, and -1 indicates no selection.
- (NSArray<NSString *> *)textView:(NSTextView *)textView completions:(NSArray<NSString *> *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(nullable NSInteger *)index {
    NSLog(@"textView completions: for range %lu-%lu '%@' selectedIndex %ld textLength:%ld", charRange.location, charRange.length,
          [textView.string substringWithRange:charRange], (long)*index, textView.textStorage.length);
    if (charRange.length==0) {
        return nil;
    }
    NSRange effectiveRange;
    NSString *txtPrefix = [[textView.string substringWithRange:charRange] lowercaseString];
    completions c = [textView.textStorage attribute:KeyCompletions atIndex:charRange.location + charRange.length-1 effectiveRange:&effectiveRange];
    if (c != nil) {
        NSLog(@"effectiveRange %lu-%lu '%@'", effectiveRange.location, effectiveRange.length, [textView.string substringWithRange:effectiveRange]);
        *index =-1;
        NSArray<NSString*>*items = c();
        return [items filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
            return [[evaluatedObject lowercaseString] hasPrefix:txtPrefix];
        }]];
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

-(void)color {
    uint64_t started = mach_absolute_time();
    NSTextStorage *txt = self.txt;
    [txt beginEditing];
    NSRange all = NSMakeRange(0, txt.length);
    [txt removeAttribute:NSToolTipAttributeName range:all];
    [txt removeAttribute:NSCursorAttributeName range:all];
    [txt removeAttribute:KeyCompletions range:all];
    
    __block double callbackTime = 0;
    tokenCallback color = ^void(SoqlTokenType t, NSRange loc, NSString *error,completions comps)  {
        uint64_t cs = mach_absolute_time();
        if (comps != nil) {
            [txt addAttribute:KeyCompletions value:comps range:loc];
        }
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
                if (error != nil) {
                    [txt addAttribute:NSToolTipAttributeName value:error range:loc];
                }
                break;
        }
        callbackTime += (mach_absolute_time()-cs);
    };
    [self enumerateTokens:txt.string describes:self block:color];
    [txt endEditing];
    NSLog(@"colorizer tool %.3fms total, incallback %.3fms", (mach_absolute_time() - started)*ticksToMillis, callbackTime*ticksToMillis);
};

-(void)enumerateTokens:(NSString *)soql describes:(NSObject<Describer>*)d block:(tokenCallback)cb {
    NSError *parseErr = nil;
    uint64_t started = mach_absolute_time();

    SelectQuery *q = [self.soqlParser parse:soql error:&parseErr];
    NSLog(@"parser took    %.3fms", (mach_absolute_time() - started)*ticksToMillis);
    if (parseErr != nil) {
        NSLog(@"parse error: %@", parseErr);
        completions cfn = ^NSArray<NSString*>*() {
            return parseErr.userInfo[@"Completions"];
        };
        cb(TError, NSMakeRange([parseErr.userInfo[@"Position"] integerValue], 1), parseErr.localizedDescription, cfn);
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

@implementation GroupBy (Colorize)
-(void)enumerateTokens:(Context*)ctx block:(tokenCallback)cb {
    // TODO fields in a groupBy must have the groupable property set.
    for (Expr *g in self.fields) {
        [g enumerateTokens:ctx block:cb];
    }
}
@end

@implementation SelectQuery (Colorize)
-(Context)queryContext:(Context*)parentCtx {
    ZKDescribeSObject *d = [parentCtx->describer describe:self.from.sobject.name.val];
    Context c = {d, nil, parentCtx->describer};
    return c;
}

-(void)enumerateFrom:(Context *)ctx block:(tokenCallback)cb {
    cb(TField, self.from.sobject.loc, nil, nil);
    if (ctx->desc == nil) {
        if (![ctx->describer knownSObject:self.from.sobject.name.val]) {
            NSObject<Describer> *describer = ctx->describer;
            cb(TError,
               self.from.sobject.name.loc,
               [NSString stringWithFormat:@"SObject %@ does not exist or is not accessible.", self.from.sobject.name.val],
               ^NSArray<NSString*>*() {
                return [describer allSObjects];
            });
            
        }
    }
    AliasMap *aliases = nil;
    if (self.from.sobject.alias.length > 0 || self.from.relatedObjects.count > 0) {
        aliases = [AliasMap dictionaryWithCapacity:self.from.relatedObjects.count + 1];
    }
    if (self.from.sobject.alias.length > 0 && ctx->desc != nil) {
        aliases[[CaseInsensitiveStringKey of:self.from.sobject.alias.val]] = ctx->desc;
    }
    // TODO, this has a large overlap with the code for SelectField below.
    for (SelectField *related in self.from.relatedObjects) {
        cb(TField, related.loc, nil, nil);
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
                cb(TError, NSUnionRange(step.loc, related.name.lastObject.loc), nil, nil);
                curr = nil;
                break;
            }
            if (df.namePointing) {
                // polymorphic rel, valid fields are from Name, not any of the actual related types.
                curr = [ctx->describer describe:@"Name"];
            } else {
                curr = [ctx->describer describe:df.referenceTo[0]];
            }
        }
        if (curr != nil) {
            aliases[[CaseInsensitiveStringKey of:related.alias.val]] = curr;
        }
    }
    ctx->aliases = aliases;
}

-(void)enumerateTokens:(Context*)ctx block:(tokenCallback)cb {
    cb(TKeyword, self.loc, nil, nil);
    Context qCtx = [self queryContext:ctx];
    [self enumerateFrom:&qCtx block:cb];
    for (Expr *f in self.selectExprs) {
        [f enumerateTokens:&qCtx block:cb];
    }
    // FilterScope ?
    [self.where enumerateTokens:&qCtx block:cb];
    if (self.withDataCategory.count > 0) {
        for (DataCategoryFilter *f in self.withDataCategory) {
            cb(TField, f.category.loc, nil, nil);
            for (PositionedString *v in f.values) {
                cb(TField, v.loc, nil, nil);
            }
        }
    }
    [self.groupBy enumerateTokens:&qCtx block:cb];
    [self.having enumerateTokens:&qCtx block:cb];
    for (OrderBy *o in self.orderBy.items) {
        [o.field enumerateTokens:&qCtx block:cb];
    }
    if (self.limit != nil) {
        cb(TLiteral, self.limit.loc, nil, nil);
    }
    if (self.offset != nil) {
        cb(TLiteral, self.offset.loc, nil, nil);
    }
}
@end

@implementation NestedSelectQuery (Colorize)
//
// TODO when this is a nested select in the select list, the from can only be a relationship.
//
-(Context)queryContext:(Context*)parentCtx {
    NSString *from = self.from.sobject.name.val;
    ZKDescribeSObject *d = [parentCtx->describer describe:from];
    // for nested selected the from may be a relationship from the parent rather than an exact type.
    if (d == nil && parentCtx->desc != nil) {
        ZKChildRelationship *cr = [parentCtx->desc childRelationshipsByName][[CaseInsensitiveStringKey of:from]];
        if (cr != nil) {
            d = [parentCtx->describer describe:cr.childSObject];
        }
    }
    Context c = {d, nil, parentCtx->describer};
    return c;
}
@end
    
@implementation SelectField (Colorize)
-(void)enumerateTokens:(Context*)ctx block:(tokenCallback)cb {
    cb(TField, self.loc, nil, nil);
    
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
            cb(TError, self.name[0].loc,
                   [NSString stringWithFormat:@"Need to add a field to the SObject %@", obj.name],
                   ^NSArray<NSString*>*() {
                        NSMutableArray<NSString*>* completions = [NSMutableArray arrayWithCapacity:obj.fields.count * 1.25];
                        for (ZKDescribeField *f in obj.fields) {
                            [completions addObject:[NSString stringWithFormat:@"%@.%@", obj.name, f.name]];
                            if (f.relationshipName.length > 0) {
                                [completions addObject:[NSString stringWithFormat:@"%@.%@", obj.name, f.relationshipName]];
                            }
                        }
                        [completions sortUsingSelector:@selector(caseInsensitiveCompare:)];
                        return completions;
            });
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
            if (obj != nil) {
                if (df == nil) {
                    cb(TError, NSUnionRange(f.loc, [self.name lastObject].loc),
                       [NSString stringWithFormat:@"There is no field or relationship %@ on SObject %@", f.val, obj.name],
                       ^NSArray<NSString*>*() {
                        NSMutableArray *c = [NSMutableArray arrayWithArray:[obj.fields valueForKey:@"name"]];
                        [c addObjectsFromArray:[obj.parentRelationshipsByName.allValues valueForKey:@"relationshipName"]];
                        [c sortUsingSelector:@selector(caseInsensitiveCompare:)];
                        return c;
                    });
                    return;
                } else if (f == self.name.lastObject) {
                    NSObject<Describer> *describer = ctx->describer;
                    cb(TError, f.loc,
                       [NSString stringWithFormat:@"%@ is a relationship, it should be followed by a field", df.relationshipName],
                       ^NSArray<NSString*>*() {
                            ZKDescribeSObject *relatedObject = [describer describe:df.referenceTo[0]]; // TODO or name;
                            NSMutableArray<NSString*>* completions = [NSMutableArray arrayWithCapacity:relatedObject.fields.count * 1.25];
                            for (ZKDescribeField *f in relatedObject.fields) {
                                [completions addObject:[NSString stringWithFormat:@"Contact.%@.%@", df.relationshipName, f.name]];
                                if (f.relationshipName.length > 0) {
                                    [completions addObject:[NSString stringWithFormat:@"%@.%@", df.relationshipName, f.relationshipName]];
                                }
                            }
                            [completions sortUsingSelector:@selector(caseInsensitiveCompare:)];
                            NSLog(@"completions %@", completions);
                            return completions;
                    });
                   return;
               }
            }
            if (df.namePointing) {
                // polymorphic rel, valid fields are from Name, not any of the actual related types.
                obj = [ctx->describer describe:@"Name"];
            } else {
                obj = [ctx->describer describe:df.referenceTo[0]];
            }
        } else {
            // its a field, it better be the last item on the path.
            if (f != path.lastObject) {
                NSRange fEnd = NSMakeRange(f.loc.location+f.loc.length,1);
                cb(TError, NSUnionRange(fEnd, path.lastObject.loc),
                   [NSString stringWithFormat:@"%@ is a field not a relationship, so should be the last item in the field path", f.val], nil);
                return;
            }
        }
    }
}
@end

@implementation SelectFunc (Colorize)
-(void)enumerateTokens:(Context*)ctx block:(tokenCallback)cb {
    cb(TFunc, self.name.loc, nil, nil);
    for (Expr *e in self.args) {
        [e enumerateTokens:ctx block:cb];
    }
    if (self.alias != nil) {
        cb(TField, self.alias.loc, nil, nil);
    }
}
@end

@implementation TypeOf (Colorize)
-(void)enumerateTokens:(Context*)ctx block:(tokenCallback)cb {
    cb(TField, self.relationship.loc, nil, nil);
    ZKDescribeSObject *objDesc = ctx->desc;
    ZKDescribeField *relField = nil;
    if (objDesc != nil) {
        relField = [objDesc parentRelationshipsByName][[CaseInsensitiveStringKey of:self.relationship.val]];
        if (relField == nil) {
            cb(TError, self.relationship.loc,
               [NSString stringWithFormat:@"There is no relationship %@ on SObject %@", self.relationship.val, ctx->desc.name],
               ^NSArray<NSString*>*() {
                    return [objDesc.parentRelationshipsByName.allValues valueForKey:@"relationshipName"];
            });
        }
    }
    for (TypeOfWhen *w in self.whens) {
        cb(TField, w.objectType.loc, nil, nil);
        ZKDescribeSObject *d = [ctx->describer describe:w.objectType.val];
        if (d == nil) {
            cb(TError, w.objectType.loc,
               [NSString stringWithFormat:@"The SObject %@ doesn't exist or is not accessible", w.objectType.val],
               ^NSArray<NSString*>*() {
                    return relField.referenceTo;
            });
        } else {
            BOOL validRefTo = FALSE;
            for (NSString *refTo in relField.referenceTo) {
                if ([refTo caseInsensitiveCompare:d.name] == NSOrderedSame) {
                    validRefTo = TRUE;
                    break;
                }
            }
            if (!validRefTo) {
                cb(TError, w.objectType.loc,
                   [NSString stringWithFormat:@"The relationship %@ does not reference the %@ SObject", self.relationship.val, d.name],
                   ^NSArray<NSString*>* {
                        return relField.referenceTo;
                });
            }
        }
        Context childCtx = { d, ctx->aliases, ctx->describer };
        for (SelectField *f in w.select) {
            [f enumerateTokens:&childCtx block:cb];
        }
    }
    ZKDescribeSObject *d = [ctx->describer describe:@"Name"];
    Context childCtx = { d, ctx->aliases, ctx->describer };
    for (SelectField *e in self.elses) {
        [e enumerateTokens:&childCtx block:cb];
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
    cb(TLiteral, self.loc, nil, nil);
}
@end

@implementation LiteralValueArray (Colorize)
-(void)enumerateTokens:(Context*)ctx block:(tokenCallback)cb {
    cb(TLiteral, self.loc, nil, nil);
}
@end
