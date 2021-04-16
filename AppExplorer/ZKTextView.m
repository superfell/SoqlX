// Copyright (c) 2016,2021 Simon Fell
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

#import "ZKTextView.h"
#include <mach/mach_time.h>

double ticksToMilliseconds;

@interface ZKTextView()
@property (strong,nonatomic) NSTimer *idleCheckTimer;
@end

@implementation ZKTextView

+(void)initialize {
    // The first time we get here, ask the system
    // how to convert mach time units to nanoseconds
    mach_timebase_info_data_t timebase;
    // to be completely pedantic, check the return code of this next call.
    mach_timebase_info(&timebase);
    ticksToMilliseconds = (double)timebase.numer / timebase.denom / 1000000;
}

- (instancetype)initWithFrame:(NSRect)frameRect textContainer:(nullable NSTextContainer *)container {
    self = [super initWithFrame:frameRect textContainer:container];
    self.idleCheckTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(checkIdle) userInfo:nil repeats:YES];
    return self;
}

-(nullable instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    self.idleCheckTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(checkIdle) userInfo:nil repeats:YES];
    hasTyped = FALSE;
    return self;
}

-(instancetype)init {
    self = [super init];
    self.idleCheckTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(checkIdle) userInfo:nil repeats:YES];
    hasTyped = FALSE;
    return self;
}

// if the user pastes rich text, we want to treat it as plain text becuase
// we're controlling the formatting
-(void)paste:(id)sender {
    [self pasteAsPlainText:sender];
}

-(void)mouseMoved:(NSEvent *)event {
    lastEvent = mach_absolute_time();
    [super mouseMoved:event];
}

-(void)keyDown:(NSEvent *)event {
    lastEvent = mach_absolute_time();
    hasTyped = TRUE;
    [super keyDown:event];
}

-(BOOL)isAtEndOfWord {
    NSRange r = [self selectedRange];
    NSLog(@"selectedRanage %lu - %lu", r.location, r.length);
    if (r.location == 0) {
        return FALSE;
    }
    if (r.location == self.textStorage.length) {
        return TRUE;
    }
    NSString *txt = self.textStorage.string;
    unichar prev = [txt characterAtIndex:r.location-1];
    unichar next = [txt characterAtIndex:r.location];
    return isblank(next) && !isblank(prev);
}

-(void)checkIdle {
    uint64_t now = mach_absolute_time();
    double idle = (now-lastEvent) * ticksToMilliseconds;
    if (hasTyped && (idle > 400)) {
        lastEvent = now;
        hasTyped = FALSE;
        if ([self isAtEndOfWord]) {
            [self complete:self];
        }
    }
}

@end
