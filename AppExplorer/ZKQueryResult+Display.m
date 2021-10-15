// Copyright 2021 Simon Fell
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
#import "ZKQueryResult+Display.h"
#import "SObject.h"

@implementation ZKQueryResult(Display)

-(id)columnDisplayValue:(NSString *)colName atRow:(NSUInteger)rowIndex {
    if (rowIndex >= records.count) {
        return nil;
    }
    ZKSObject *row = records[rowIndex];
    if ([colName isEqualToString:DELETE_COLUMN_IDENTIFIER]) {
        return @(row.checked);
    }
    if ([colName isEqualToString:ERROR_COLUMN_IDENTIFIER]) {
        return row.errorMsg;
    }
    if ([colName isEqualToString:TYPE_COLUMN_IDENTIFIER]) {
        return row.type;
    }
    NSArray *fieldPath = [colName componentsSeparatedByString:@"."];
    NSObject *val = row;
    for (NSString *step in fieldPath) {
        if ([val isKindOfClass:[ZKSObject class]]) {
            val = [(ZKSObject *)val fieldValue:step];
        } else {
            val = [val valueForKey:step];
        }
    }
    if ([[val class] isSubclassOfClass:[ZKXmlDeserializer class]]) {
        return val.description;
    }
    return val;
}

@end
