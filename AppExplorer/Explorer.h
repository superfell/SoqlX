// Copyright (c) 2006-2012 Simon Fell
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

#import <Cocoa/Cocoa.h>
#import "DataSources.h"
#import "SchemaController.h"
#import "StandAloneTableHeaderView.h"
#import "zkSforceClient.h"
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

@interface Explorer : NSObject<EditableQueryResultWrapperDelegate, NSTabViewDelegate>
{
	// old world order, needs modernizing
    IBOutlet NSOutlineView			*describeList;
    IBOutlet NSTableView			*rootTableView;
	IBOutlet NSTableView			*childTableView;
    IBOutlet NSTextView			    *soql;	
	IBOutlet NSProgressIndicator	*progress;
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

- (IBAction)showLogin:(id)sender;
- (IBAction)showInBrowser:(id)sender;
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


