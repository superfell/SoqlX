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


#import "TStamp.h"

double ticksToMilliseconds;

static BOOL enableLogging = YES;

@interface LoggingTStamp : TStamp {
   uint64_t                    *marks;
   NSInteger                   cap;
   NSMutableArray<NSString*>   *names;
}
@end

@implementation TStamp

+(void)initialize {
    // The first time we get here, ask the system
    // how to convert mach time units to milliseconds
    mach_timebase_info_data_t timebase;
    // to be completely pedantic, check the return code of this next call.
    mach_timebase_info(&timebase);
    ticksToMilliseconds = (double)timebase.numer / timebase.denom / 1000000;
}

+(instancetype)start {
    return enableLogging ? [[LoggingTStamp alloc] init] : nil;
}

-(void)mark:(NSString*)s {}
-(void)log {}

@end

@implementation LoggingTStamp

-(instancetype)init {
    self = [super init];
    names = [NSMutableArray arrayWithObject:@"Start"];
    cap = 4;
    marks = malloc(cap * sizeof(uint64_t));
    marks[0] = mach_absolute_time();
    return self;
}

-(void)dealloc {
    free(marks);
}

-(void)mark:(NSString*)name {
    uint64_t t = mach_absolute_time();
    if (names.count == cap) {
        marks = realloc(marks, cap * 2 * sizeof(uint64_t));
        cap *= 2;
    }
    marks[names.count] = t;
    [names addObject:name];
}

-(NSString*)description {
    NSMutableString *d = [NSMutableString stringWithString:names[0]];
    [names enumerateObjectsUsingBlock:^(NSString * _Nonnull name, NSUInteger idx, BOOL * _Nonnull stop) {
        if (idx == 0) return;
        [d appendFormat:@" -%@: %.3fms", name, (marks[idx] - marks[idx-1]) * ticksToMilliseconds];
    }];
    [d appendFormat:@" / overall: %.3fms", (marks[names.count-1] - marks[0]) * ticksToMilliseconds];
    return d;
}

-(void)log {
    NSLog(@"%@", [self description]);
}

@end
