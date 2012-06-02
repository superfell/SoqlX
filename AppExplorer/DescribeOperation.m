//
//  DescribeOperation.m
//  AppExplorer
//
//  Created by Simon Fell on 1/6/08.
//  Copyright 2008 Simon Fell. All rights reserved.
//

#import "DescribeOperation.h"
#import "DataSources.h"

NSString *DescribeDidFinish = @"DescribeDidFinish";
NSString *DescribeKey = @"Describe";

@implementation DescribeOperation

- (id)initForSObject:(NSString *)entity cache:(DescribeListDataSource *)cache {
	self = [self init];
	sobject = [entity copy];
	dataSource = [cache retain];
	return self;
}

- (void)dealloc {
	[sobject release];
	[dataSource release];
	[super dealloc];
}

- (void)main {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	ZKDescribeSObject *desc = [dataSource describe:sobject];
	NSDictionary *info = [NSDictionary dictionaryWithObject:desc forKey:DescribeKey];
	[[NSNotificationCenter defaultCenter] postNotificationName:DescribeDidFinish object:self userInfo:info];
	[pool release];
}

@end
