/* StandAloneTableHeaderView */

#import <Cocoa/Cocoa.h>

@interface StandAloneTableHeaderView : NSView {
	NSString 		*headerText;
	NSDictionary 	*textAttributes;
	NSGradient		*gradient;
}

- (void)setHeaderText:(NSString *)newValue;
- (NSString *)headerText;

@end
