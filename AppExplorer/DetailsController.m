// Copyright (c) 2007-2012 Simon Fell
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

#import "DetailsController.h"
#import "../common/NSWindow_additions.h"

@implementation DetailsController

+(NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
    NSSet *paths = [super keyPathsForValuesAffectingValueForKey:key];
    if ([key isEqualToString:@"title"])
        return [paths setByAddingObject:@"dataSource"];
    return paths;
}

-(void)awakeFromNib {
	[window setAlphaValue:0.0];
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"details"])
		[self updateDetailsState:self];
}

-(IBAction)updateDetailsState:(id)sender {
	[window displayOrCloseWindow:sender];
}

-(NSString *)title {
	if ([self dataSource] == nil) return @"Details";
	return [[self dataSource] description];
}

-(NSObject *)dataSource {
	return [detailsTable dataSource];
}

-(void)setDataSource:(NSObject *)aValue {
	NSObject *oldDataSource = [self dataSource];
	[detailsTable setDataSource:aValue];
	[aValue retain];
	[oldDataSource release];
}

-(void)windowWillClose:(NSNotification *)notification {
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"details"];
	[[window animator] setAlphaValue:0.0];
}

@end
