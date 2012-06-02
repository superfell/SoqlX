//
//  DescribeOperation.h
//  AppExplorer
//
//  Created by Simon Fell on 1/6/08.
//  Copyright 2008 Simon Fell. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class ZKSforceClient;
@class DescribeListDataSource;

// NSNotification name that indicates we now have the describe info for a particular type
extern NSString *DescribeDidFinish;
// key in the userInfo dictionary that contains the DescribeSObject instance
extern NSString *DescribeKey;	

@interface DescribeOperation : NSOperation {
	NSString					*sobject;
	DescribeListDataSource		*dataSource;
}

- (id)initForSObject:(NSString *)sobject cache:(DescribeListDataSource *)cache;

@end
