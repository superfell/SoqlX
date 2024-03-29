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

#import <objc/runtime.h>
#import "SObject.h"

NSString *DELETE_COLUMN_IDENTIFIER = @"row__delete";
NSString *ERROR_COLUMN_IDENTIFIER = @"row__error";
NSString *TYPE_COLUMN_IDENTIFIER = @"row__type";

@implementation ZKSObject (SoqlX)

-(void)setChecked:(BOOL)checked {
    objc_setAssociatedObject(self, @selector(setChecked:), @(checked), OBJC_ASSOCIATION_RETAIN);
}
-(BOOL)checked {
    return [objc_getAssociatedObject(self, @selector(setChecked:)) boolValue];
}

-(void)setErrorMsg:(NSString*)msg {
    objc_setAssociatedObject(self, @selector(setErrorMsg:), msg, OBJC_ASSOCIATION_RETAIN);
}
-(NSString*)errorMsg {
    return objc_getAssociatedObject(self, @selector(setErrorMsg:));
}

-(NSObject *)valueForFieldPathArray:(NSArray<NSString*> *)fieldPath {
    if (fieldPath.count == 1) {
        return [self fieldValue:fieldPath[0]];
    }
    id val = self;
    for (NSString *step in fieldPath) {
        if ([val isKindOfClass:[ZKSObject class]]) {
            val = [(ZKSObject *)val fieldValue:step];
        } else {
            val = [val valueForKey:step];
        }
    }
    return val;
}

@end
