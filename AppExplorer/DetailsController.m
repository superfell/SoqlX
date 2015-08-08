// Copyright (c) 2007-2015 Simon Fell
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
#import "NSWindow_additions.h"
#import "NSTableView_additions.h"

static NSString *SHOWING_DETAILS = @"details";

@implementation DetailsController

+(NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
    NSSet *paths = [super keyPathsForValuesAffectingValueForKey:key];
    if ([key isEqualToString:@"title"])
        return [paths setByAddingObject:@"dataSource"];
    return paths;
}

-(void)dealloc {
    [dataSourceRef release];
    [super dealloc];
}

-(NSString *)windowVisiblePrefName {
    return SHOWING_DETAILS;
}

-(NSString *)title {
	if ([self dataSource] == nil) return @"Details";
	return [[self dataSource] description];
}

-(NSObject *)dataSource {
	return [detailsTable dataSource];
}

-(void)setDataSource:(NSObject<NSTableViewDataSource> *)aValue {
    [dataSourceRef autorelease];
    dataSourceRef = [aValue retain];
	[detailsTable setDataSource:aValue];
}

- (void)setIcon:(NSImage *)image {
    [[detailsTable window] setRepresentedURL:[NSURL fileURLWithPath:self.title]];
    [[[detailsTable window] standardWindowButton:NSWindowDocumentIconButton] setImage:image];
}

- (IBAction) copy:(id)sender {
    [detailsTable zkCopyTableDataToClipboard];
}

@end
