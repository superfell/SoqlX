//
//  DetailsController.h
//  AppExplorer
//
//  Created by Simon Fell on 1/21/07.
//  Copyright 2007 Simon Fell. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface DetailsController : NSObject {
	IBOutlet NSPanel			*window;
	IBOutlet NSTableView		*detailsTable;
}
- (IBAction)updateDetailsState:(id)sender;
- (NSObject *)dataSource;
- (void)setDataSource:(NSObject *)aValue;
- (NSString *)title;

@end
