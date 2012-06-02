// Copyright (c) 2006 Simon Fell
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

#import "WeightedSObject.h"

@implementation WeightedSObject

+(id)weightedSObjectForSObject:(NSString *)sobjectName {
	return [[[WeightedSObject alloc] initForSObject:sobjectName] autorelease];
}

-(id)initForSObject:(NSString *)sobjectName {
	self = [super init];
	sobject = [sobjectName copy];
	weight = [[NSMutableIndexSet alloc] init];
	return self;
}

-(void)dealloc {
	[sobject release];
	[weight release];
	[super dealloc];
}

-(NSString *)sobject {
	return sobject;
}

-(void)addWeight:(uint)index {
	[weight addIndex:index];
}

-(NSIndexSet *)weights {
	return weight;
}

-(NSComparisonResult)compare:(WeightedSObject *)other
{
	// start by looking at the last field connected to
	double left = [[self weights] lastIndex];
	double right = [[other weights] lastIndex];
	if (left < right) return NSOrderedAscending;
	else if (left > right) return NSOrderedDescending;
	// if we're both connected to the same top field, go by the number of other connections
	left = [[self weights] count];
	right = [[other weights] count];
	if (left < right) return NSOrderedDescending;
	else if (left > right) return NSOrderedAscending;
	// last resort, sort on name
	return [sobject compare:[other sobject]];
}

@end
