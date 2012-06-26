// Copyright (c) 2007 Simon Fell
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

#import "ZKCodeCoverageResult.h"
#import "ZKCodeLocation.h"

@implementation ZKCodeCoverageResult

- (NSArray *)dmlInfo {
	return [self complexTypeArrayFromElements:@"dmlInfo" cls:[ZKCodeLocation class]];
}

- (NSArray *)locationsNotCovered {
	return [self complexTypeArrayFromElements:@"locationsNotCovered" cls:[ZKCodeLocation class]];
}

- (NSArray *)methodInfo {
	return [self complexTypeArrayFromElements:@"methodInfo" cls:[ZKCodeLocation class]];
}

- (NSString *)name {
	return [self string:@"name"];
}

- (NSString *)namespace {
	return [self string:@"namespace"];
}

- (int)numLocations {
	return [self integer:@"numLocations"];
}

- (int)numLocationsNotCovered {
	return [self integer:@"numLocationsNotCovered"];
}

- (NSArray *)soqlInfo {
	return [self complexTypeArrayFromElements:@"soqlInfo" cls:[ZKCodeLocation class]];
}

- (NSString *)type {
	return [self string:@"type"];
}

@end
