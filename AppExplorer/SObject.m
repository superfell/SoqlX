// Copyright (c) 2020 Simon Fell
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

#import "SObject.h"
#import <ZKSforce/ZKSforce.h>

@interface SObject ()

@property (readwrite) ZKSObject *src;
@property (readwrite) describeProvider describer;
@property (readwrite) ZKDescribeSObject *describe;

@end

typedef id(^mapper)(ZKSObject*,NSString*);

@interface TypeMapper : NSObject
+(TypeMapper*)instance;
@property NSDictionary<NSString*, mapper> *mappings;
-(id)valueOfField:(NSString *)field ofType:(NSString *)type from:(ZKSObject *)o;
@end

@implementation TypeMapper

+(TypeMapper*)instance {
    static TypeMapper *m = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        m = [[TypeMapper alloc] init];
    });
    return m;
}

-(instancetype)init {
    self = [super init];
    self.mappings = @{
        @"xsd:boolean": ^id(ZKSObject *o, NSString *f){ return @([o boolValue:f]);   },
        @"xsd:double" : ^id(ZKSObject *o, NSString *f){ return @([o doubleValue:f]); },
        @"xsd:int" :    ^id(ZKSObject *o, NSString *f){ return @([o intValue:f]);    },
        @"xsd:date":    ^id(ZKSObject *o, NSString *f){ return [o dateValue:f];      },
        @"xsd:dateTime":^id(ZKSObject *o, NSString *f){ return [o dateTimeValue:f];  },
    };
    return self;
}

-(id)valueOfField:(NSString *)field ofType:(NSString *)type from:(ZKSObject *)o {
    mapper m = self.mappings[type];
    if (m == nil) {
        return [o fieldValue:field];
    }
    return m(o, field);
}

@end


@implementation SObject

+(instancetype)wrap:(id)src provider:(describeProvider)d {
    if ([src isKindOfClass:[SObject class]]) {
        return src;
    }
    return [[SObject alloc] initWithSObject:src prodivder:d];
}

-(instancetype)initWithSObject:(ZKSObject *)src prodivder:(describeProvider)d {
    self = [super init];
    self.src = src;
    self.describer = d;
    // we also need to wrap any nested sobjects that are field values
    [src.fields enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if ([obj isKindOfClass:[ZKSObject class]]) {
            [src setFieldValue:[SObject wrap:obj provider:d] field:key];
        }
    }];
    return self;
}

-(ZKDescribeSObject *)provideDescribe {
    if (self.describe == nil) {
        self.describe = self.describer(self.src.type);
    }
    return self.describe;
}

-(id)typedValueOf:(NSString *)field {
    id v = [self.src fieldValue:field];
    if (v == nil) {
        return v;
    }
    if ([v isKindOfClass:[NSString class]]) {
        ZKDescribeSObject *d = [self provideDescribe];
        if (d != nil) {
            ZKDescribeField *f = [d fieldWithName:field];
            if (f != nil) {
                return [[TypeMapper instance] valueOfField:field ofType:f.soapType from:self.src];
            }
        }
    }
    return v;
}

-(id)forwardingTargetForSelector:(SEL)sel {
    return self.src;
}

-(id)valueForUndefinedKey:(NSString *)key {
    if ([key isEqualToString:@"row__delete"]) {
        return @(self.deleteChecked);
    }
    id v = [[self.src fields] objectForKey:key];
    if (v == nil) {
        return [super valueForUndefinedKey:key];
    }
    return [self typedValueOf:key];
}

@end


@implementation ZKSObject (SoqlX)

-(id)valueForUndefinedKey:(NSString *)key {
    if ([key isEqualToString:@"row__delete"]) {
        return @(self.deleteChecked);
    }
    id v = self.fields[key];
    if (v == nil) {
        return [super valueForUndefinedKey:key];
    }
    return [self typedValueOf:key];
}

-(id)typedValueOf:(NSString *)field {
    id v = [self fieldValue:field];
    if (v == nil) {
        return v;
    }
    if ([v isKindOfClass:[NSString class]]) {
        ZKDescribeSObject *d = self.describer(self.type);
        if (d != nil) {
            ZKDescribeField *f = [d fieldWithName:field];
            if (f != nil) {
                return [[TypeMapper instance] valueOfField:field ofType:f.soapType from:self];
            }
        }
    }
    return v;
}


@end

