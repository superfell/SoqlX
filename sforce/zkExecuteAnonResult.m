//
//  zkExecuteAnonResult.m
//  apexCoder
//
//  Created by Simon Fell on 6/9/07.
//  Copyright 2007 Simon Fell. All rights reserved.
//

#import "zkExecuteAnonResult.h"

@implementation ZKExecuteAnonymousResult

- (int)column {
	return [self integer:@"column"];
}
- (int)line {
	return [self integer:@"line"];
}
- (BOOL)compiled {
	return [self boolean:@"compiled"];
}
- (NSString *)compileProblem {
	return [self string:@"compileProblem"];
}
- (NSString *)exceptionMessage {
	return [self string:@"exceptionMessage"];
}
- (NSString *)exceptionStackTrace {
	return [self string:@"exceptionStackTrace"];
}
- (BOOL)success {
	return [self boolean:@"success"];
}

@end
