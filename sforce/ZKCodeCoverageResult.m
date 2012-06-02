//
//  ZKCodeCoverageResult.m
//  apexCoder
//
//  Created by Simon Fell on 6/10/07.
//  Copyright 2007 Simon Fell. All rights reserved.
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
