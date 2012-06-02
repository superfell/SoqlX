//
//  WeightedField.m
//  AppExplorer
//
//  Created by Simon Fell on 11/13/06.
//  Copyright 2006 Simon Fell. All rights reserved.
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
