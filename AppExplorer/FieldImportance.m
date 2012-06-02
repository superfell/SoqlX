// Copyright (c) 2006 Simon Fell
//
// Permission is hereby granted, free of charge, to any person obtaining a 
// copy of this software and associated documentation files (the "Software"), 
// to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense, 
// and/or sell copies of the Software, and to permit persons to whom the 
// Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included 
// in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS 
// OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN 
// THE SOFTWARE.
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
