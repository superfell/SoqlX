//
//  HighlightTextFieldCell.h
//  AppExplorer
//
//  Created by Simon Fell on 3/11/09.
//  Copyright 2009 Simon Fell. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface HighlightTextFieldCell : NSTextFieldCell {
	BOOL	zkStandout;
}

-(BOOL)zkStandout;
-(void)setZkStandout:(BOOL)h;

@end
