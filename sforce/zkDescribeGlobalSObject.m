// Copyright (c) 2009-2010 Simon Fell
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

#import "zkDescribeGlobalSObject.h"


@implementation ZKDescribeGlobalSObject

-(BOOL)activateable {
	return [self boolean:@"activateable"];
}
-(BOOL)createable {
	return [self boolean:@"createable"];
}
-(BOOL)custom {
	return [self boolean:@"custom"];
}
-(BOOL)customSetting {
	return [self boolean:@"customSetting"];
}
-(BOOL)deletable {
	return [self boolean:@"deletable"];
}
-(BOOL)deprecatedAndHidden {
	return [self boolean:@"deprecatedAndHidden"];
}
-(BOOL)feedEnabled {
	return [self boolean:@"feedEnabled"];
}
-(BOOL)layoutable {
	return [self boolean:@"layoutable"];
}
-(BOOL)mergeable {
	return [self boolean:@"mergeable"];
}
-(BOOL)queryable {
	return [self boolean:@"queryable"];
}
-(BOOL)replicateable {
	return [self boolean:@"replicateable"];
}
-(BOOL)retrieveable {
	return [self boolean:@"retrieveable"];
}
-(BOOL)searchable {
	return [self boolean:@"searchable"];
}
-(BOOL)triggerable {
	return [self boolean:@"triggerable"];
}
-(BOOL)undeleteable {
	return [self boolean:@"undeleteable"];
}
-(BOOL)updateable {
	return [self boolean:@"updateable"];
}
-(NSString *)keyPrefix {
	return [self string:@"keyPrefix"];
}
-(NSString *)label {
	return [self string:@"label"];
}
-(NSString *)labelPlural {
	return [self string:@"labelPlural"];
}
-(NSString *)name {
	return [self string:@"name"];
}

@end
