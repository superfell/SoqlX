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

#import <Foundation/Foundation.h>
#import "Describer.h"

@class Tokens;
@class ZKDescribeSObject;
@class DescribeListDataSource;
@class ZKTextView;

@protocol TokenizerDescriber
-(ZKDescribeSObject*)describe:(NSString*)obj;   // returns the describe if we have it?
-(BOOL)knownSObject:(NSString*)obj;             // is the object in the describeGlobal list of objects?
-(NSArray<NSString*>*)allQueryableSObjects;
-(NSImage *)iconForSObject:(NSString *)type;
@end

@interface DLDDescriber : NSObject<TokenizerDescriber, DescriberDelegate>
+(instancetype)describer:(DescribeListDataSource *)describes;
@property (copy,nonatomic) void(^onNewDescribe)(void);
@end

@interface SoqlTokenizer : NSObject<NSTextViewDelegate, NSTextStorageDelegate>
@property (strong,nonatomic) id<TokenizerDescriber> describer;
@property (strong,nonatomic) ZKTextView *view;
-(void)color;
// for testing
-(Tokens*)parseAndResolve:(NSString*)soql;
-(void)setDebugOutputTo:(NSString*)filename;
@end
