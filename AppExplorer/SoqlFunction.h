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
#import "SoqlToken.h"

@class Completion;
@class CaseInsensitiveStringKey;
@class ZKDescribeSObject;

typedef NSString*(^ExampleProvider)(ZKDescribeSObject*);

@interface SoqlFuncArg : NSObject
+(instancetype)arg:(TokenType)type ex:(ExampleProvider)ex;
@property (assign,nonatomic) TokenType type;
@property (strong,nonatomic) NSPredicate *fieldFilter;
@property (strong,nonatomic) NSPredicate *funcFilter;
@property (copy,  nonatomic) ExampleProvider example;
// validate the supplied token against this argument, returns a new (typically error)
// token if needed.
-(Token*)validateToken:(Token*)tkn;
@end

@interface SoqlFunction : NSObject
+(NSDictionary<CaseInsensitiveStringKey*,SoqlFunction*>*)all;

+(instancetype)fn:(NSString*)name args:(NSArray<SoqlFuncArg*>*)args;

@property (strong,nonatomic) NSString *name;
@property (strong,nonatomic) NSArray<SoqlFuncArg*>* args;
-(Completion*)completionOn:(ZKDescribeSObject*)primary;
// returns an error token if there's a problem
-(Token*)validateArgCount:(Token*)tFunc;
@end

