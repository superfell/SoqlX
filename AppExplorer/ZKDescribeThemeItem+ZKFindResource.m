// Copyright (c) 2013 Simon Fell
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

#import "ZKDescribeThemeItem+ZKFindResource.h"

@implementation ZKDescribeThemeResult(ZKFindResource)
-(ZKDescribeThemeItem *)themeForItem:(NSString *)name {
    for (ZKDescribeThemeItem *i in self.themeItems)
        if ([i.name isEqualToString:name])
            return i;
    return nil;
}

@end

@implementation ZKDescribeThemeItem (ZKFindResource)

-(ZKDescribeIcon *)iconWithHeight:(NSInteger)height theme:(NSString *)theme {
    for (ZKDescribeIcon *i in [self icons]) {
        if (i.height == height && [i.theme isEqualToString:theme])
            return i;
    }
    return nil;
}

-(ZKDescribeColor *)colorWithTheme:(NSString *)theme {
    for (ZKDescribeColor *c in [self colors]) {
        if ([c.theme isEqualToString:theme])
            return c;
    }
    return nil;
}

@end


@implementation ZKDescribeIcon (ZKFetch)
-(void)fetchIconUsingSessionId:(NSString *)sid whenCompleteDo:(void (^)(NSImage *))completeBlock {
    static NSOperationQueue *queue = nil;
    if (queue == nil) {
        queue = [[NSOperationQueue alloc] init];
        [queue setName:@"image queue"];
        queue.maxConcurrentOperationCount = 2;
    }
    
    NSURL *theUrl = [NSURL URLWithString:[self url]];
    [queue addOperationWithBlock:^{
        NSMutableURLRequest *r = [[[NSMutableURLRequest alloc] initWithURL:theUrl] autorelease];
        [r setCachePolicy:NSURLCacheStorageAllowed];
        [r setHTTPShouldHandleCookies:NO];
        [r setHTTPShouldUsePipelining:NO];
        [r setHTTPMethod:@"GET"];
        NSHTTPURLResponse *res;
        NSError *err;
        NSData *d = [NSURLConnection sendSynchronousRequest:r returningResponse:&res error:&err];
        if ([res statusCode] == 200) {
            NSImage *i = [[[NSImage alloc] initWithData:d] autorelease];
            if (i != nil) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completeBlock(i);
                });
                return;
            }
        }
        NSLog(@"failed to load image from url %@", theUrl);
    }];
}

@end