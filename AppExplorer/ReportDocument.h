/* ReportDocument */

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@class DescribeListDataSource;
@class SchemaView;

@interface ReportDocument : NSDocument {
    IBOutlet WebView				*webview;
	IBOutlet SchemaView				*schemaView;
	IBOutlet NSTabView				*tabview;
	IBOutlet NSProgressIndicator	*progress;
	
	NSString 			*sobjectType;
	int					totalObjects;
	int					describesDone;
	BOOL				enabledButtons;
}

- (IBAction)print:(id)sender;
- (IBAction)saveAsPdf:(id)sender;

- (NSString *)name;
- (void)setSObjectType:(NSString *)type andDataSource:(DescribeListDataSource *)newDataSource;
- (int)totalObjects;
- (void)setTotalObjects:(int)newTotalObjects;
- (int)describesDone;
- (void)setDescribesDone:(int)newDescribesDone;
- (BOOL)enabledButtons;
- (void)setEnabledButtons:(BOOL)newEnabledButtons;

@end
