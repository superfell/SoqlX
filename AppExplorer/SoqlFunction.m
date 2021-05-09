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
+(instancetype)arg:(TokenType)type fldPred:(NSString*)fieldFilter fnPred:(NSPredicate *)fnFilter {
    SoqlFuncArg *a = [self new];
    a.type = type;
    a.fieldFilter = [NSPredicate predicateWithFormat:fieldFilter];
    a.example = firstFieldP(a.fieldFilter);
    a.funcFilter = fnFilter;
    return a;
}

+(instancetype)arg:(TokenType)type fldPred:(NSString*)fieldFilter {
    return [self arg:type fldPred:fieldFilter fnPred:nil];
}

+(instancetype)arg:(TokenType)type ex:(ExampleProvider)ex {
    SoqlFuncArg *a = [self new];
    a.type = type;
    a.example = ex;
    return a;
}
-(Token*)validateToken:(Token*)argToken {
    if ((self.type & argToken.type) != argToken.type) {
        Token *err = [argToken tokenOf:argToken.loc];
        err.type = TTError;
        err.value = [NSString stringWithFormat:@"Function argument of unexpected type %@, should be %@", tokenName(argToken.type), tokenNames(self.type)];
        return err;
    }
    if (((self.type & TTFunc) != 0) && argToken.type == TTFunc && self.funcFilter != nil) {
        SoqlFunction *fn = [SoqlFunction all][[CaseInsensitiveStringKey of:argToken.tokenTxt]];
        if (![self.funcFilter evaluateWithObject:fn]) {
            Token *err = [argToken tokenOf:argToken.loc];
            err.type = TTError;
            err.value = [NSString stringWithFormat:@"Function %@ can't be used as this argument", argToken.tokenTxt];
            return err;
        }
    }
    if (((self.type & TTFieldPath) != 0) && argToken.type==TTFieldPath && self.fieldFilter != nil) {
        if ([argToken.value isKindOfClass:[Tokens class]]) {
            Tokens *pathTokens = (Tokens*)argToken.value;
            Token *lastPathToken = pathTokens.tokens.lastObject;
            if (lastPathToken.type == TTField) {
                ZKDescribeField *f = (ZKDescribeField *)lastPathToken.value;
                if (![self.fieldFilter evaluateWithObject:f]) {
                    Token *err = [argToken tokenOf:argToken.loc];
                    err.type = TTError;
                    err.value = [NSString stringWithFormat:@"Field %@ is not valid for this function", argToken.tokenTxt];
                    return err;
                }
            }
        }
    }
    return nil;
}
@end

@interface DistanceMeasureArg : SoqlFuncArg
@end

@implementation DistanceMeasureArg
-(instancetype)init {
    self = [super init];
    self.type = TTLiteralString;
    self.example = fixed(@"'mi'");
    return self;
}

-(Token*)validateToken:(Token*)argToken {
    [argToken.completions addObjectsFromArray:[Completion completions:@[@"'mi'", @"'km'"] type:TTLiteralString]];
    Token *err = [super validateToken:argToken];
    if (err == nil) {
        if ((![argToken matches:@"'mi'"]) && (![argToken matches:@"'km'"])) {
            err = [argToken tokenOf:argToken.loc];
            err.type = TTError;
            err.value = @"Function argument should be 'mi' or 'km'";
        }
    }
    return err;
}

@end

@interface FieldsArg : SoqlFuncArg
@end
@implementation FieldsArg
-(instancetype)init {
    self = [super init];
    self.type = TTKeyword;
    self.example = fixed(@"STANDARD");
    return self;
}
-(Token*)validateToken:(Token*)argToken {
    NSArray<NSString*> *valid = @[@"STANDARD", @"ALL", @"CUSTOM"];
    [argToken.completions addObjectsFromArray:[Completion completions:valid type:TTKeyword]];
    if (argToken.type == TTFieldPath) {
        argToken.type = TTKeyword;
    }
    Token *err = [super validateToken:argToken];
    if (err == nil) {
        for (NSString *v in valid) {
            if ([argToken matches:v]) {
                return nil;
            }
        }
        argToken.type = TTError;
        argToken.value = [NSString stringWithFormat:@"Fields argument should be one of %@", [valid componentsJoinedByString:@","]];
    }
    return err;
}

@end

@interface SoqlCountFunction : SoqlFunction
@end

@implementation SoqlCountFunction
-(instancetype)init {
    self = [super init];
    self.name = @"Count";
    self.args = @[[SoqlFuncArg arg:TTFieldPath fldPred:@"aggregatable=true"]];
    return self;
}
-(Token*)validateArgCount:(Token*)tFunc {
    // count is different in that there's both count() and count(field)
    Tokens *args = (Tokens*)tFunc.value;
    if (args.count == 0) {
        return nil;
    }
    return [super validateArgCount:tFunc];
}

@end

@implementation SoqlFunction

+(NSDictionary<CaseInsensitiveStringKey*,SoqlFunction*>*)all {
    static dispatch_once_t onceToken;
    static NSDictionary<CaseInsensitiveStringKey*,SoqlFunction*>* funcs;
    
    dispatch_once(&onceToken, ^{
        SoqlFunction *cvtTz = [self fn:@"ConvertTimezone" args:@[[SoqlFuncArg arg:TTFieldPath fldPred:@"type='datetime' OR type='date'"]]];
        NSPredicate *cvzTzOnly = [NSPredicate predicateWithFormat:@"name=%@", cvtTz.name];
        
        SoqlFunction *geoLoc = [self fn:@"Geolocation" args:@[[SoqlFuncArg arg:TTLiteralNumber ex:fixed(@"1.0")], [SoqlFuncArg arg:TTLiteralNumber ex:fixed(@"1.0")]]];
        SoqlFuncArg *distGeoArg = [SoqlFuncArg arg:TTFunc ex:fixed(@"GeoLocation(1.0,1.0)")];
        distGeoArg.funcFilter = [NSPredicate predicateWithFormat:@"name=%@", geoLoc.name];
        
        SoqlFunction *convCurrency = [self fn:@"ConvertCurrency" args:@[[SoqlFuncArg arg:TTFieldPath fldPred:@"type='currency'"]]];
        NSPredicate *convCurrencyOnly = [NSPredicate predicateWithFormat:@"name=%@", convCurrency.name];

        NSArray<SoqlFunction*>* fns = @[
            [self fn:@"Fields" args:@[[FieldsArg new]]],
            [self fn:@"ToLabel" args:@[[SoqlFuncArg arg:TTFieldPath fldPred:@"type!='id' AND type!='reference'"]]],
            [SoqlCountFunction new],
            [self fn:@"Count_Distinct" args:@[[SoqlFuncArg arg:TTFieldPath fldPred:@"aggregatable=true"]]],
            [self fn:@"Avg" args:@[[SoqlFuncArg arg:TTFieldPath | TTFunc fldPred:@"aggregatable=true AND (type='double' OR type='integer' OR type='currency')" fnPred:convCurrencyOnly]]],
            [self fn:@"Sum" args:@[[SoqlFuncArg arg:TTFieldPath | TTFunc fldPred:@"aggregatable=true AND (type='double' OR type='integer' OR type='currency')" fnPred:convCurrencyOnly]]],
            [self fn:@"Min" args:@[[SoqlFuncArg arg:TTFieldPath | TTFunc fldPred:@"aggregatable=true AND type!='id' AND type!='reference'" fnPred:convCurrencyOnly]]],
            [self fn:@"Max" args:@[[SoqlFuncArg arg:TTFieldPath | TTFunc fldPred:@"aggregatable=true AND type!='id' AND type!='reference'" fnPred:convCurrencyOnly]]],
            [self fn:@"Format" args:@[[SoqlFuncArg arg:TTFieldPath | TTFunc
                                               fldPred:@"type='datetime' OR type='date' OR type='time' or type='currency' or type='double' or type='integer'"]]],
            [self fn:@"Distance" args:@[[SoqlFuncArg arg:TTFieldPath fldPred:@"type='location'"],
                                        distGeoArg,
                                        [DistanceMeasureArg new]]],
            [self fn:@"Calendar_Month" args:@[[SoqlFuncArg arg:TTFieldPath | TTFunc fldPred:@"type='datetime' OR type='date'" fnPred:cvzTzOnly]]],
            [self fn:@"Calendar_Quarter" args:@[[SoqlFuncArg arg:TTFieldPath| TTFunc fldPred:@"type='datetime' OR type='date'" fnPred:cvzTzOnly]]],
            [self fn:@"Calendar_Year" args:@[[SoqlFuncArg arg:TTFieldPath | TTFunc fldPred:@"type='datetime' OR type='date'" fnPred:cvzTzOnly]]],
            [self fn:@"Day_In_Month" args:@[[SoqlFuncArg arg:TTFieldPath | TTFunc fldPred:@"type='datetime' OR type='date'" fnPred:cvzTzOnly]]],
            [self fn:@"Day_In_Week" args:@[[SoqlFuncArg arg:TTFieldPath | TTFunc fldPred:@"type='datetime' OR type='date'" fnPred:cvzTzOnly]]],
            [self fn:@"Day_In_Year" args:@[[SoqlFuncArg arg:TTFieldPath | TTFunc fldPred:@"type='datetime' OR type='date'" fnPred:cvzTzOnly]]],
            [self fn:@"Day_Only" args:@[[SoqlFuncArg arg:TTFieldPath | TTFunc fldPred:@"type='datetime'" fnPred:cvzTzOnly]]],
            [self fn:@"Fiscal_Month" args:@[[SoqlFuncArg arg:TTFieldPath | TTFunc fldPred:@"type='datetime' OR type='date'" fnPred:cvzTzOnly]]],
            [self fn:@"Fiscal_Quarter" args:@[[SoqlFuncArg arg:TTFieldPath | TTFunc fldPred:@"type='datetime' OR type='date'" fnPred:cvzTzOnly]]],
            [self fn:@"Fiscal_Year" args:@[[SoqlFuncArg arg:TTFieldPath | TTFunc fldPred:@"type='datetime' OR type='date'" fnPred:cvzTzOnly]]],
            [self fn:@"Hour_In_Day" args:@[[SoqlFuncArg arg:TTFieldPath | TTFunc fldPred:@"type='datetime'" fnPred:cvzTzOnly]]],
            [self fn:@"Week_In_Month" args:@[[SoqlFuncArg arg:TTFieldPath | TTFunc fldPred:@"type='datetime' OR type='date'" fnPred:cvzTzOnly]]],
            [self fn:@"Week_In_Year" args:@[[SoqlFuncArg arg:TTFieldPath | TTFunc fldPred:@"type='datetime' OR type='date'" fnPred:cvzTzOnly]]],
            [self fn:@"Grouping" args:@[[SoqlFuncArg arg:TTFieldPath fldPred:@"groupable=TRUE"]]],

            convCurrency, cvtTz, geoLoc
        ];
        NSMutableDictionary *d = [NSMutableDictionary dictionaryWithCapacity:fns.count];
        for (SoqlFunction *f in fns) {
            [d setObject:f forKey:[CaseInsensitiveStringKey of:f.name]];
        }
        funcs = [NSDictionary dictionaryWithDictionary:d];
    });
    return funcs;
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
    [s appendString:@"("];
    if (self.args.count > 0) {
        NSEnumerator<SoqlFuncArg*> *e = [self.args objectEnumerator];
        [s appendString:e.nextObject.example(primary)];
        posAtEndOfFirstArg = s.length;
        SoqlFuncArg *arg = e.nextObject;
        while (arg != nil) {
            [s appendString:@","];
            [s appendString:arg.example(primary)];
            arg = e.nextObject;
        }
    }
    [s appendString:@")"];
    Completion *fc = [Completion txt:self.name type:TTFunc];
    fc.finalInsertionText = s;
    if (posAtEndOfFirstArg > 0) {
        fc.onFinalInsert = moveSelection(-(s.length-posAtEndOfFirstArg));
    }
    return fc;
}

-(Token*)validateArgCount:(Token*)tFunc {
    Tokens *argTokens = (Tokens*)tFunc.value;
    if (argTokens.count != self.args.count) {
        Token *err = [tFunc tokenOf:tFunc.loc];
        err.type = TTError;
        err.value = [NSString stringWithFormat:@"The function %@ should have %ld arguments, but has %ld", self.name, self.args.count, argTokens.count];
        return err;
    }
    return nil;
}

@end
