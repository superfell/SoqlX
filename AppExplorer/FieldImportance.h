//
//  FieldImportance.h
//  AppExplorer
//
//  Created by Simon Fell on 11/15/06.
//  Copyright 2006 Simon Fell. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "../sforce/zkDescribeField.h"
#import "SObjectViewMode.h"

@interface ZKDescribeField (FieldImportance)
-(int)importance;
-(BOOL)shouldDisplayInMode:(SObjectBoxViewMode)mode;
@end
