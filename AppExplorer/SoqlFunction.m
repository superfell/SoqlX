//
//  SoqlFunction.m
//  SoqlXplorer
//
//  Created by Simon Fell on 4/27/21.
//

#import "SoqlFunction.h"
#import "CaseInsensitiveStringKey.h"
#import "SoqlToken.h"
#import <ZKSforce/ZKSforce.h>

ExampleProvider firstFieldP(NSPredicate*p) {
    return ^NSString*(ZKDescribeSObject*o) {
        for (ZKDescribeField *f in o.fields) {
            if ([p evaluateWithObject:f]) {
                return f.name;
            }
        }
        return @"Id";
    };
}
ExampleProvider firstField(NSString*p) {
    return firstFieldP([NSPredicate predicateWithFormat:p]);
}
ExampleProvider fixed(NSString*value) {
    return ^NSString*(ZKDescribeSObject*o) {
        return value;
    };
}

@implementation SoqlFuncArg
+(instancetype)arg:(TokenType)type pred:(NSString*)fieldFilter {
    SoqlFuncArg *a = [self new];
    a.type = type;
    a.fieldFilter = [NSPredicate predicateWithFormat:fieldFilter];
    a.example = firstFieldP(a.fieldFilter);
    return a;
}

+(instancetype)arg:(TokenType)type ex:(ExampleProvider)ex {
    SoqlFuncArg *a = [self new];
    a.type = type;
    a.example = ex;
    return a;
}
@end

@implementation SoqlFunction

+(NSDictionary<CaseInsensitiveStringKey*,SoqlFunction*>*)all {
    NSArray<SoqlFunction*>* fns = @[
        [self fn:@"MIN" args:@[[SoqlFuncArg arg:TTFieldPath pred:@"aggregatable=true AND type!='id' AND type!='reference'"]]],
        [self fn:@"MAX" args:@[[SoqlFuncArg arg:TTFieldPath pred:@"aggregatable=true AND type!='id' AND type!='reference'"]]],
        [self fn:@"FORMAT" args:@[[SoqlFuncArg arg:TTFieldPath ex:firstField(@"type='datetime'")]]],
        [self fn:@"DISTANCE" args:@[[SoqlFuncArg arg:TTFieldPath pred:@"type='location'"],
                                    [SoqlFuncArg arg:TTFunc ex:fixed(@"GEOLOCATION(1.0,1.0)")],
                                    [SoqlFuncArg arg:TTLiteral ex:fixed(@"\'mi\'")]]],
        [self fn:@"GEOLOCATION" args:@[[SoqlFuncArg arg:TTLiteral ex:fixed(@"1.0")], [SoqlFuncArg arg:TTLiteral ex:fixed(@"1.0")]]]
    ];
    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithCapacity:fns.count];
    for (SoqlFunction *f in fns) {
        [d setObject:f forKey:[CaseInsensitiveStringKey of:f.name]];
    }
    return [NSDictionary dictionaryWithDictionary:d];
}

+(instancetype)fn:(NSString*)name args:(NSArray<SoqlFuncArg*>*)args {
    SoqlFunction *f = [self new];
    f.name = name;
    f.args = args;
    return f;
}

-(Completion*)completionOn:(ZKDescribeSObject*)primary {
    NSMutableString *s = [NSMutableString stringWithCapacity:32];
    NSInteger posAtEndOfFirstArg = 0;
    [s appendString:self.name];
    if (self.args.count > 0) {
        [s appendString:@"("];
        NSEnumerator<SoqlFuncArg*> *e = [self.args objectEnumerator];
        [s appendString:e.nextObject.example(primary)];
        posAtEndOfFirstArg = s.length;
        SoqlFuncArg *arg = e.nextObject;
        while (arg != nil) {
            [s appendString:@","];
            [s appendString:arg.example(primary)];
            arg = e.nextObject;
        }
        [s appendString:@")"];
    }
    Completion *fc = [Completion txt:self.name type:TTFunc];
    fc.finalInsertionText = s;
    if (posAtEndOfFirstArg > 0) {
        fc.onFinalInsert = moveSelection(-(s.length-posAtEndOfFirstArg));
    }
    return fc;
}

@end
