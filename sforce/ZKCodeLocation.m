//
//  ZKCodeLocation.m
//  apexCoder
//
//  Created by Simon Fell on 6/10/07.
//  Copyright 2007 Simon Fell. All rights reserved.
//

#import "ZKCodeLocation.h"


@implementation ZKCodeLocation

- (int)column {
	return [self integer:@"column"];
}

- (int)line {
	return [self integer:@"line"];
}

- (int)numExecutions {
	return [self integer:@"numExecutions"];	
}

- (double)time {
	return [self double:@"time"];
}

@end
