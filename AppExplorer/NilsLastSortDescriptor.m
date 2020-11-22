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

#import "NilsLastSortDescriptor.h"

@implementation NilsLastSortDescriptor

- (NSComparisonResult)compareObject:(id)object1 toObject:(id)object2 {
    id val1 = [object1 valueForKeyPath:self.key];
    id val2 = [object2 valueForKeyPath:self.key];
    if (val1 == val2) {
        return NSOrderedSame;
    }
    NSComparisonResult r;
    if (val1 == nil) {
        r = NSOrderedDescending;
    } else if (val2 == nil) {
        r = NSOrderedAscending;
    } else {
        r = self.comparator(val1,val2);
    }
    return self.ascending ? r : -r;
}

-(id)reversedSortDescriptor {
    return [[[self class] alloc] initWithKey:self.key ascending:!self.ascending comparator:self.comparator];
}

@end
