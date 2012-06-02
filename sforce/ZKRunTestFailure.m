//
//  ZKRunTestFailure.m
//  apexCoder
//
//  Created by Simon Fell on 6/10/07.
//  Copyright 2007 Simon Fell. All rights reserved.
//

#import "ZKRunTestFailure.h"


@implementation ZKRunTestFailure

- (NSString *)message {
	return [self string:@"message"];
}

- (NSString *)namespace {
	return [self string:@"namespace"];
}

- (NSString *)packageName {
	return [self string:@"packageName"];
}

- (NSString *)methodName {
	return [self string:@"methodName"];	
}

- (NSString *)stackTrace {
	return [self string:@"stackTrace"];
}

@end
