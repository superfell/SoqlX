//
//  WeightedField.h
//  AppExplorer
//
//  Created by Simon Fell on 11/13/06.
//  Copyright 2006 Simon Fell. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface WeightedSObject : NSObject {
	NSString			*sobject;
	NSMutableIndexSet	*weight;
}

+ (id)weightedSObjectForSObject:(NSString *)sobjectName;

- (id)initForSObject:(NSString *)sobjectName;
- (NSString *)sobject;
- (void)addWeight:(uint)index;
- (NSIndexSet *)weights;
- (NSComparisonResult)compare:(WeightedSObject *)other;
@end
