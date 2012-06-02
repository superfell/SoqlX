//
//  ZKCompilePackageResult.m
//  apexCoder
//
//  Created by Simon Fell on 6/8/07.
//  Copyright 2007 Simon Fell. All rights reserved.
//

#import "ZKCompileResult.h"


@implementation ZKCompileResult

-(NSString *)userName {
	return [self string:@"userName"];
}

- (BOOL)success {
	return [self boolean:@"success"];
}

- (NSString *)id {
	return [self string:@"id"];
}

- (NSString *)problem {
	return [self string:@"problem"];
}

- (int)bodyCrc {
	return [self integer:@"bodyCrc"];
}

- (int)column {
	return [self integer:@"column"];
}

- (int)line {
	return [self integer:@"line"];
}

@end
