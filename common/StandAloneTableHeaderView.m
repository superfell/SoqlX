#import "StandAloneTableHeaderView.h"


@implementation StandAloneTableHeaderView

-(id)initWithFrame:(NSRect)rect {
	[super initWithFrame:rect];
	textAttributes =  [[NSMutableDictionary dictionaryWithObjectsAndKeys:
						[NSFont titleBarFontOfSize:11.0], NSFontAttributeName,
						[NSColor blackColor], NSForegroundColorAttributeName,
						nil] retain];
						
	gradient = [[NSGradient alloc] initWithColors:[NSArray arrayWithObjects:[NSColor whiteColor], [NSColor colorWithCalibratedRed:0.875 green:0.875 blue:0.875 alpha:1.0], [NSColor whiteColor], nil]];
	return self;
}

-(void)dealloc {
	[headerText release];
	[textAttributes release];
	[gradient release];
	[super dealloc];
}

-(void)drawRect:(NSRect)rect {
	NSRect b = [self bounds];
	[[NSColor colorWithCalibratedRed:0.698 green:0.698 blue:0.698 alpha:1.0] set];
	NSRectFill(b);
	[gradient drawInRect:NSInsetRect(b,1,1) angle:90];
	NSRect txtRect = NSInsetRect(b, 5,1);
	[headerText drawInRect:txtRect withAttributes:textAttributes];
}

-(void)setHeaderText:(NSString *)newValue {
	if (newValue != headerText) {
		[headerText release];
		headerText = [newValue copy];
	}
}

-(NSString *)headerText {
	return [[headerText retain] autorelease];
}

@end
