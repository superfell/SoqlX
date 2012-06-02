/* Explorer */

#import <Cocoa/Cocoa.h>
#import "DataSources.h"
#import "SchemaController.h"
#import "StandAloneTableHeaderView.h"
#import "../sforce/zkSforceClient.h"
#import "EditableQueryResultWrapper.h"

@class ReportWizardController;
@class DetailsController;
@class LoginController;
@class ZKLoginController;
@class EditableQueryResultWrapper;
@class ZKSObject;
@class ZKQueryResult;
@class QueryResultTable;
@class QueryListController;
@class ApexController;

@interface Explorer : NSObject<EditableQueryResultWrapperDelegate>
{
	// old world order, needs modernizing
    IBOutlet NSOutlineView			*describeList;
    IBOutlet NSTableView			*rootTableView;
	IBOutlet NSTableView			*childTableView;
    IBOutlet NSTextView			    *soql;	
	IBOutlet NSProgressIndicator	*progress;
	IBOutlet NSWindow				*prefsWindow;
	IBOutlet NSWindow				*myWindow;
	IBOutlet NSTabView				*soqlSchemaTabs;
	IBOutlet NSSplitView			*vertSplitView;
	IBOutlet NSSplitView			*soqlTextSplitView;
	
	IBOutlet StandAloneTableHeaderView	*soqlHeader;
	
	ZKSforceClient					*sforce;
	DescribeListDataSource			*descDataSource;

	QueryResultTable				*rootResults;
	QueryResultTable				*childResults;
	CGFloat							uncollapsedDividerPosition;
	
	ZKLoginController 				*loginController;
	IBOutlet SchemaController		*schemaController;
	IBOutlet DetailsController		*detailsController;
	IBOutlet QueryListController	*queryListController;
	IBOutlet ApexController			*apexController;
	
	// new world order, uses binding
	NSString						*statusText;
	BOOL							schemaViewIsActive;
}

- (IBAction)launchHelp:(id)sender;
- (IBAction)showLogin:(id)sender;
- (IBAction)showInBrowser:(id)sender;
- (IBAction)showPreferences:(id)sender;
- (IBAction)closePreferences:(id)sender;
- (IBAction)executeQuery:(id)sender;
- (IBAction)executeQueryAll:(id)sender;
- (IBAction)queryMore:(id)sender;
- (IBAction)selectedSObjectChanged:(id)sender;
- (IBAction)describeItemClicked:(id)sender;
- (IBAction)generateReportForSelection:(id)sender;
- (IBAction)queryResultDoubleClicked:(id)sender;
- (IBAction)showSelectedIdFronRootInBrowser:(id)sender;
- (IBAction)showSelectedIdFronChildInBrowser:(id)sender;
- (IBAction)saveQueryResults:(id)sender;
- (IBAction)deleteSelectedRow:(id)sender;
- (IBAction)deleteCheckedRows:(id)sender;
- (IBAction)filterSObjectListView:(id)sender;

- (NSString *)statusText;
- (void)setStatusText:(NSString *)aValue;
- (BOOL)schemaViewIsActive;
- (void)setSchemaViewIsActive:(BOOL)active;
- (BOOL)isLoggedIn;
- (BOOL)hasSelectedForDelete;
- (BOOL)canQueryMore;
- (NSArray *)SObjects;
- (DescribeListDataSource *)describeDataSource;
- (ZKDescribeSObject *)selectedSObject;
- (void)updateProgress:(BOOL)show;

- (void)dataChangedOnObject:(ZKSObject *)anObject field:(NSString *)fieldName value:(id)newValue;

@end


