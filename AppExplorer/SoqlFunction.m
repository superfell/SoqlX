//
//  SoqlFunction.m
//  SoqlXplorer
//
//  Created by Simon Fell on 4/27/21.
//

#import "SoqlFunction.h"
#import "CaseInsensitiveStringKey.h"

@implementation SoqlFuncArg
+(instancetype)arg:(TokenType)type ex:(NSString*)ex {
    SoqlFuncArg *a = [self new];
    a.type = type;
    a.exampleValue = ex;
    return a;
}
@end

@implementation SoqlFunction
+(NSDictionary<CaseInsensitiveStringKey*,SoqlFunction*>*)all {
    NSArray<SoqlFunction*>* fns = @[
        [self fn:@"MIN" args:@[[SoqlFuncArg arg:TTFieldPath ex:@"CreatedDate"]]],
        [self fn:@"MAX" args:@[[SoqlFuncArg arg:TTFieldPath ex:@"CreatedDate"]]],
        [self fn:@"FORMAT" args:@[[SoqlFuncArg arg:TTFieldPath ex:@"CreatedDate"]]],
        [self fn:@"DISTANCE" args:@[[SoqlFuncArg arg:TTFieldPath ex:@"Location__c"],
                                    [SoqlFuncArg arg:TTFunc ex:@"GEOLOCATION(1.0,1.0)"],
                                    [SoqlFuncArg arg:TTLiteral ex:@"\'mi\'"]]],
        [self fn:@"GEOLOCATION" args:@[[SoqlFuncArg arg:TTLiteral ex:@"1.0"], [SoqlFuncArg arg:TTLiteral ex:@"1.0"]]]
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
@end
