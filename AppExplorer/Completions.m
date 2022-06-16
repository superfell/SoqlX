// Copyright (c) 2022 Simon Fell
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
#import "Completions.h"

@interface CompletionLocations()
@property NSMutableArray<NSArray<Completion*>*>* items;
@end

@implementation CompletionLocations

// These have been stored directly in the AttributedString in the past with a custom key
// but storing lots (100's) of those gets progressively slower and slower. So we stash
// then in here instead, in an manner that just has to deal with our specific use case.

-(id)init {
    self = [super init];
    self.items = [NSMutableArray arrayWithCapacity:256];
    return self;
}

-(void)clear {
    [self.items removeAllObjects];
}

-(void)add:(NSArray<Completion*>*)completions at:(NSRange)loc {
    // we simply stash the completions away at every point in the range
    // in the self.items array. The size of self.items will be ~ the length
    // of the parsed SOQL.
    NSUInteger end = NSMaxRange(loc);
    if (self.items.count < end) {
        NSArray *empty = [NSArray array];
        while (self.items.count < end) {
            [self.items addObject:empty];
        }
    }
    for (NSUInteger p = loc.location; p < end; ++p) {
        self.items[p] = completions;
    }
}

-(NSArray<Completion*>*)completionsInRange:(NSRange)loc {
    // look for the first non empty array starting at the end and going backwards.
    if (self.items.count == 0) {
        return [NSArray array];
    }
    for (NSUInteger p = MIN(self.items.count, NSMaxRange(loc))-1; p >= loc.location; --p) {
        NSArray *r = self.items[p];
        if (r.count > 0) {
            return r;
        }
    }
    return [NSArray array];
}

@end
