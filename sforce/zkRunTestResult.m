//
//  zkRunTestResult.m
//  apexCoder
//
//  Created by Simon Fell on 6/10/07.
//  Copyright 2007 Simon Fell. All rights reserved.
//

#import "zkRunTestResult.h"
#import "zkRunTestFailure.h"
#import "zkCodeCoverageResult.h"

@implementation ZKRunTestResult

- (NSArray *)codeCoverage {
	return [self complexTypeArrayFromElements:@"codeCoverage" cls:[ZKCodeCoverageResult class]];
}

- (NSArray *)failures {
	return  [self complexTypeArrayFromElements:@"failures" cls:[ZKRunTestFailure class]];
}

- (int)numFailures {
	return [self integer:@"numFailures"];
}

- (int)numTestsRun {
	return [self integer:@"numTestsRun"];
}

@end
