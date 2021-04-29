//
//  ColorizerStyle.m
//  AppExplorer
//
//  Created by Simon Fell on 4/17/21.
//

#import "ColorizerStyle.h"
#import <objc/runtime.h>
#import "CaseInsensitiveStringKey.h"

static ColorizerStyle *style;

@implementation ColorizerStyle

+(void)initialize {
    style = [ColorizerStyle new];
}

+(instancetype)styles {
    return style;
}

-(instancetype)init {
    self = [super init];
    self.fieldColor = [NSColor colorNamed:@"soql.field"];
    self.keywordColor = [NSColor colorNamed:@"soql.keyword"];
    self.literalColor = [NSColor colorNamed:@"soql.literal"];
    
    self.underlineStyle = @(NSUnderlineStyleSingle | NSUnderlinePatternDot | NSUnderlineByWord);
    self.underlined = @{
                        NSUnderlineStyleAttributeName: self.underlineStyle,
                        NSUnderlineColorAttributeName: [NSColor yellowColor],
                        };
    self.noUnderline = @{ NSUnderlineStyleAttributeName: @(NSUnderlineStyleNone) };
    
    // TODO, why is colorNamed:@ returning nil in unit tests?
    if (self.keywordColor != nil) {
        self.keyWord = @{ NSForegroundColorAttributeName:self.keywordColor};
        self.field =   @{ NSForegroundColorAttributeName:self.fieldColor};
        self.literal = @{ NSForegroundColorAttributeName:self.literalColor};
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
            if (f.relationshipName.length > 0 && f.referenceTo.count > 0) {
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
            if (r.relationshipName.length > 0) {
                [cr setObject:r forKey:[CaseInsensitiveStringKey of:r.relationshipName]];
            }
        }
        r = cr;
        objc_setAssociatedObject(self, @selector(childRelationshipsByName), r, OBJC_ASSOCIATION_RETAIN);
    }
    return r;
}

@end
