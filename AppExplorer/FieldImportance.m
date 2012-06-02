//
//  FieldImportance.m
//  AppExplorer
//
//  Created by Simon Fell on 11/15/06.
//  Copyright 2006 Simon Fell. All rights reserved.
//

#import "FieldImportance.h"

@implementation ZKDescribeField (FieldImportance)

-(BOOL)isUserReference:(BOOL)userOnly {
	if (![[self type] isEqualTo:@"reference"]) return NO;
	NSArray *references = [self referenceTo];
	if (!userOnly && ([references count] == 1)) return NO;
	if (userOnly && ([references count] != 1)) return NO;
	return [references containsObject:@"User"];
}

-(BOOL)isReferenceToOnlyUser {
	return [self isUserReference:YES];
}

-(BOOL)isPolyReferenceIncludingUser {
	return [self isUserReference:NO];
}

// todo, make magic numbers go away
-(int)importance {
	if ([[self name] isEqualToString:@"Id"])
		return 1;
	if ([self nameField])
		return 2;
	if ([self externalId])
		return 3;
	if ([self isPolyReferenceIncludingUser])
		return 5;
	if ([self isReferenceToOnlyUser])
		return 6;
	if ([[self name] isEqualToString:@"CreatedDate"])
		return 7;
	if ([[self name] isEqualToString:@"LastModifiedDate"])
		return 8;
	if ([[self name] isEqualToString:@"SystemModstamp"])
		return 9;
	return 4;
}

-(BOOL)shouldDisplayInMode:(SObjectBoxViewMode)viewMode {
	if (viewMode == vmTitleOnly) 
		return [self importance] <= 2;
	if (viewMode == vmImportantFields)
		return [self importance] <= 3 || ![self custom];
	return true;
}

@end
