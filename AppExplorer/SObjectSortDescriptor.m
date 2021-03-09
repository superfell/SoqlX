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

#import "SObjectSortDescriptor.h"
#import <ZKSforce/ZKSforce.h>

@interface SObjectSortDescriptor ()
- (NSComparisonResult)compareValue:(id)val1 toValue:(id)val2;
- (id)typedValueOf:(NSString *)key from:(ZKSObject *)row;
@end

@implementation SObjectSortDescriptor

-(instancetype)initWithKey:(NSString *)key ascending:(BOOL)ascending describer:(describeProvider)d {
    self = [super initWithKey:key ascending:ascending];
    self.describer = d;
    return self;
}

- (NSComparisonResult)compareObject:(id)object1 toObject:(id)object2 {
    id val1 = [self typedValueOf:self.key from:object1];
    id val2 = [self typedValueOf:self.key from:object2];
    if (val1 == val2) {
        return NSOrderedSame;
    }
    NSComparisonResult r;
    if (val1 == nil) {
        r = NSOrderedDescending;
    } else if (val2 == nil) {
        r = NSOrderedAscending;
    } else {
        r = [self compareValue:val1 toValue:val2];
    }
    return self.ascending ? r : -r;
}

-(id)reversedSortDescriptor {
    return [[[self class] alloc] initWithKey:self.key ascending:!self.ascending describer:self.describer];
}

- (NSComparisonResult)compareValue:(id)val1 toValue:(id)val2 {
    if ([val1 isKindOfClass:[NSString class]] && [val2 isKindOfClass:[NSString class]]) {
        NSString *s1 = (NSString *)val1;
        NSString *s2 = (NSString *)val2;
        return [s1 compare:s2 options:NSCaseInsensitiveSearch];
    }
    if ([val1 isKindOfClass:[ZKQueryResult class]] && [val2 isKindOfClass:[ZKQueryResult class]]) {
        val1 = @([(ZKQueryResult *)val1 size]);
        val2 = @([(ZKQueryResult *)val2 size]);
    }
    if ([[val1 class] isSubclassOfClass:[ZKXmlDeserializer class]]) {
        val1 = [val1 description];
        val2 = [val2 description];
    }
    return [val1 compare:val2];
}

-(id)typedValueOf:(NSString *)key from:(ZKSObject *)row {
    if ([key isEqualToString:DELETE_COLUMN_IDENTIFIER]) {
        return @(row.checked);
    }
    if ([key isEqualToString:ERROR_COLUMN_IDENTIFIER]) {
        return row.errorMsg;
    }
    if ([key isEqualToString:TYPE_COLUMN_IDENTIFIER]) {
        return row.type;
    }
    NSArray *fieldPath = [key componentsSeparatedByString:@"."];
    NSObject *val = row;
    for (NSString *step in fieldPath) {
        if ([val isKindOfClass:[ZKSObject class]]) {
            ZKSObject *o = (ZKSObject*)val;
            val = [o typedValueOfField:step withDescribe:self.describer(o.type)];
        } else {
            val = [val valueForKey:step];
        }
    }
    return val;
}

@end
