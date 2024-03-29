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
    return [self columnPathDisplayValue:[colName componentsSeparatedByString:@"."] atRow:rowIndex];
}

-(id)columnPathDisplayValue:(NSArray<NSString*>*)colPath atRow:(NSUInteger)rowIndex {
    if (rowIndex >= records.count) {
        return nil;
    }
    ZKSObject *row = records[rowIndex];
    if (colPath.count == 1) {
        if ([colPath[0] isEqualToString:DELETE_COLUMN_IDENTIFIER]) {
            return @(row.checked);
        }
        if ([colPath[0] isEqualToString:ERROR_COLUMN_IDENTIFIER]) {
            return row.errorMsg;
        }
        if ([colPath[0] isEqualToString:TYPE_COLUMN_IDENTIFIER]) {
            return row.type;
        }
    }
    NSObject *val = [row valueForFieldPathArray:colPath];
    if ([[val class] isSubclassOfClass:[ZKXmlDeserializer class]]) {
        return val.description;
    }
    return val;
}

-(NSObject *)valueForFieldPathArray:(NSArray<NSString*> *)fieldPath row:(NSInteger)row {
    return [records[row] valueForFieldPathArray:fieldPath];
}

@end
