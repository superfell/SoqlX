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

#import "Explorer.h"
#import "ReportDocument.h"
#import "detailsController.h"
#import "ZKLoginController.h"
#import "EditableQueryResultWrapper.h"
#import "DescribeOperation.h"
#import "QueryResultTable.h"
#import "QueryListController.h"
#import "QueryTextListView.h"
#import "ApexController.h"
#import "zkSforce.h"
#import "ResultsSaver.h"
#import "BulkDelete.h"
#import <Sparkle/Sparkle.h>

static NSString *schemaTabId = @"schema";
static CGFloat MIN_PANE_SIZE = 128.0f;

@interface Explorer ()
- (IBAction)initUi:(id)sender;
- (IBAction)postLogin:(id)sender;
- (void)closeLoginPanelIfOpen:(id)sender;

- (void)setSoqlString:(NSString *)soql;
- (NSString *)soqlString;

- (void)colorize;
- (NSString *)parseEntityName:(NSArray *)words;

- (void)describeFinished:(NSNotification *)notification;

- (void)collapseChildTableView;
- (void)openChildTableView;
@end

@implementation Explorer

+ (void)initialize {
	NSMutableDictionary * defaults = [NSMutableDictionary dictionary];
	[defaults setObject:[NSNumber numberWithBool:NO] forKey:@"details"];
	[defaults setObject:@"select id, firstname, lastname from contact" forKey:@"soql"];

	NSString *prod = @"https://www.salesforce.com";
	NSString *test = @"https://test.salesforce.com";
	
	NSMutableArray * defaultServers = [NSMutableArray arrayWithObjects:prod, test, nil];
	[defaults setObject:defaultServers forKey:@"systems"];
	[defaults setObject:prod forKey:@"system"];
	[[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}

+(NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
    NSSet *paths = [super keyPathsForValuesAffectingValueForKey:key];
    if ([key isEqualToString:@"canQueryMore"])
        return [paths setByAddingObjectsFromArray:[NSArray arrayWithObjects:@"currentResults", @"rowsLoadedStatusText", nil]];
    return paths;
}

- (void)awakeFromNib {
	[myWindow setContentBorderThickness:28.0 forEdge:NSMinYEdge]; 	
	[myWindow setContentBorderThickness:28.0 forEdge:NSMaxYEdge]; 	

	// Turn on full-screen option in Lion
	//if ([myWindow respondsToSelector:@selector(setCollectionBehavior:)]) {
	//	[myWindow setCollectionBehavior:[myWindow collectionBehavior] | (1 << 7)];
	//}
	
	[soqlSchemaTabs setDelegate:self];
	[soqlHeader setHeaderText:@"SOQL Query"];
	[self setStatusText:@""];
	
	[progress setUsesThreadedAnimation:YES];
	[describeList setDoubleAction:@selector(describeItemClicked:)];	
	[rootTableView setTarget:self];
	[rootTableView setDoubleAction:@selector(queryResultDoubleClicked:)];
	rootResults = [[QueryResultTable alloc] initForTableView:rootTableView];
	[rootResults setDelegate:self];
	[rootResults addObserver:self forKeyPath:@"hasCheckedRows" options:0 context:nil];
	childResults = [[QueryResultTable alloc] initForTableView:childTableView];
	[childResults setDelegate:self];
	[self collapseChildTableView];
	
    [self performSelector:@selector(initUi:) withObject:nil afterDelay:0];
    // If the updater is going to restart the app, we need to close the login sheet if its currently open.
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(closeLoginPanelIfOpen:) name:SUUpdaterWillRestartNotification object:nil];
    
    // A describeSObject operation has finished, see if we can recolor our soql text. (this is going to pick up describes from other windows, but it
    // doesn't matter for now, as the color code re-checks to see if the describe result is available)
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(describeFinished:) name:DescribeDidFinish object:nil];
    
    [queryListController setDelegate:self];
}

- (void)dealloc {
	[sforce release];
	[descDataSource release];
	[loginController release];
	[statusText release];
	[rootResults removeObserver:self forKeyPath:@"hasCheckedRows"];
	[rootResults release];
	[childResults release];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

- (void)collapseChildTableView {
	if (![soqlTextSplitView isSubviewCollapsed:[[childTableView superview] superview]]) {
		NSRect viewFrame = [[[childTableView superview] superview] frame];
		uncollapsedDividerPosition = viewFrame.origin.y + viewFrame.size.height;
		[soqlTextSplitView setPosition:[soqlTextSplitView maxPossiblePositionOfDividerAtIndex:1] ofDividerAtIndex:1];
	}
}

- (void)openChildTableView {
	if ([soqlTextSplitView isSubviewCollapsed:[[childTableView superview] superview]]) {
		CGFloat p = [soqlTextSplitView maxPossiblePositionOfDividerAtIndex:1] - MIN_PANE_SIZE;
		[soqlTextSplitView setPosition:p ofDividerAtIndex:1];
	}
}

- (NSString *)statusText {
	return statusText;
}

- (void)setStatusText:(NSString *)aValue {
	NSString *oldStatusText = statusText;
	statusText = [aValue retain];
	[oldStatusText release];
}

- (BOOL)schemaViewIsActive {
	return schemaViewIsActive;
}

- (void)setSchemaViewIsActive:(BOOL)active {
	schemaViewIsActive = active;
}

- (IBAction)initUi:(id)sender {
	[self setSoqlString:[[NSUserDefaults standardUserDefaults] stringForKey:@"soql"]];
    [self performSelector:@selector(showLogin:) withObject:nil afterDelay:0];
}

- (IBAction)showLogin:(id)sender {
	[loginController release];
	loginController = [[ZKLoginController alloc] init];
	[loginController setClientIdFromInfoPlist];
	NSNumber *apiVersion = [[NSUserDefaults standardUserDefaults] objectForKey:@"zkApiVersion"];
	if (apiVersion != nil)
		[loginController setPreferedApiVersion:[apiVersion intValue]];
	[loginController showLoginSheet:myWindow target:self selector:@selector(loginComplete:)];
}
	
- (void)loginComplete:(ZKSforceClient *)sf {
	[sforce release];
	sforce = [sf retain];
	[loginController release];
	loginController = nil;
    [self performSelector:@selector(postLogin:) withObject:nil afterDelay:0];
}

- (void)closeLoginPanelIfOpen:(id)sender {
	[loginController cancelLogin:sender];
}

- (BOOL)isLoggedIn {
	return [sforce loggedIn];
}

- (void)launchSfdcBrowser:(NSString *)retUrl {
	ZKDescribeSObject *d = [descDataSource describe:@"Task"];
	NSURL *url = [NSURL URLWithString:[d urlNew]];
	NSURL *baseUiUrl = [NSURL URLWithString:@"/" relativeToURL:url];
	retUrl = retUrl == nil ? @"" : [NSString stringWithFormat:@"&retURL=%@", retUrl];
	NSURL *fd = [NSURL URLWithString:[NSString stringWithFormat:@"/secur/frontdoor.jsp?sid=%@%@", [sforce sessionId], retUrl] relativeToURL:baseUiUrl];
	[[NSWorkspace sharedWorkspace] openURL:fd];
}

- (IBAction)showInBrowser:(id)sender {
	[self launchSfdcBrowser:nil];
}

- (void)updateProgress:(BOOL)show {
	[progress setDoubleValue:show ? 50 : 0];
	if (show)
		[progress startAnimation:self];
	else
		[progress stopAnimation:self];
	[progress setHidden:!show];
	[progress display];
}

- (IBAction)postLogin:(id)sender {
	NSString *msg = [NSString stringWithFormat:@"Welcome %@ (instance:%@)",
                        [[sforce currentUserInfo] fullName],
                        [[sforce serverUrl] host]];
	[self setStatusText:msg];
    
    NSString *title = [NSString stringWithFormat:@"SoqlX : %@ (%@ on %@)",
                       [[sforce currentUserInfo] fullName],
                       [[sforce currentUserInfo] userName],
                       [sforce serverHostAbbriviation]];
    [myWindow setTitle:title];
    NSString *userId = [[sforce currentUserInfo] userId];
	[queryListController setPrefPrefix:userId];
    [detailsController setPrefsPrefix:userId];

	NSArray * types = [sforce describeGlobal];
	[descDataSource release];
	descDataSource = [[DescribeListDataSource alloc] init];
	[self willChangeValueForKey:@"SObjects"];
	[apexController setSforceClient:sforce];
	[descDataSource setSforce:sforce];
	[descDataSource setTypes:types view:describeList];
	[describeList setDataSource:descDataSource];
	[describeList setDelegate:descDataSource];
	[describeList reloadData];
	[self didChangeValueForKey:@"SObjects"];

	[schemaController setDescribeDataSource:descDataSource];
	[self colorize];
	[self updateProgress:NO];
	[self willChangeValueForKey:@"isLoggedIn"];
	[self didChangeValueForKey:@"isLoggedIn"];
	[rootResults setQueryResult:nil];
	[childResults setQueryResult:nil];
}

- (void)setSoqlString:(NSString *)str {
	[[soql textStorage] setAttributedString:[[[NSAttributedString alloc] initWithString:str] autorelease]];
	[self colorize];
}

- (void)queryTextListView:(QueryTextListView *)listView itemClicked:(QueryTextListViewItem *)item {
	NSString *t = [item text];
	if (t == nil || [t length] == 0) return;
	[self setSoqlString:t];
}

- (NSString *)soqlString {
	return [[soql textStorage] string];
}

typedef enum SoqlParsePosition {
	sppStart,
	sppFields,
	sppFrom,
	sppWhere,
	sppWhereAndOr,
	sppWhereNot,
	sppWhereField,
	sppWhereOperator,
	sppWhereLiteral
} SoqlParsePosition;
	
-(void)textDidChange:(NSNotification *)notification {
    [self colorize];
}

-(void)describeFinished:(NSNotification *)notification {
	[self performSelectorOnMainThread:@selector(colorize) withObject:nil waitUntilDone:NO];
}

- (NSString *)parseEntityName:(NSArray *)words {
	NSMutableAttributedString *w;
	BOOL atFrom = NO;
	NSEnumerator *e = [words objectEnumerator];
	while (w = [e nextObject]) {
		if (atFrom)
			return [w string];
		if ([[w string] caseInsensitiveCompare:@"from"] == NSOrderedSame)
			atFrom = YES;
	}
	return nil;
}

- (void)colorize {
	NSColor *fieldColor = [NSColor colorWithCalibratedRed:0.25 green:0.25 blue:0.8 alpha: 1.0];
	NSColor *keywordColor = [NSColor colorWithCalibratedRed: 0.8 green:0.25 blue:0.25 alpha: 1.0];

	NSNumber *underlineStyle = [NSNumber numberWithInt:(NSUnderlineStyleSingle | NSUnderlinePatternDot | NSUnderlineByWordMask)];
	NSMutableDictionary *underlined = [NSMutableDictionary dictionary];
	[underlined setObject:underlineStyle forKey:NSUnderlineStyleAttributeName];
	[underlined setObject:[NSColor redColor] forKey:NSUnderlineColorAttributeName];

	NSMutableDictionary *noUnderline = [NSMutableDictionary dictionary];
	[noUnderline setObject:[NSNumber numberWithInt:NSUnderlineStyleNone] forKey:NSUnderlineStyleAttributeName];
	
	[[soql textStorage] setFont:[NSFont userFixedPitchFontOfSize:11.0f]];
		
	NSArray * words = [[soql textStorage] words];
	NSString *entity = [self parseEntityName:words];
	ZKDescribeSObject *desc = nil;
	if (entity != nil) {
		if ([descDataSource hasDescribe:entity])
			desc = [descDataSource describe:entity];
		else if ([descDataSource isTypeDescribable:entity]) {
			[descDataSource prioritizeDescribe:entity];
		}
	}
	SoqlParsePosition p = sppStart;
	NSMutableAttributedString *w;
	NSEnumerator *e = [words objectEnumerator];
	BOOL isKeyword, underline;
	while (w = [e nextObject]) {
		isKeyword = NO;
		underline = NO;
		if (p == sppStart && NSOrderedSame == [[w string] caseInsensitiveCompare:@"select"]) {
			p = sppFields;
			isKeyword = YES;
		} else if (p == sppFields) {
			if (NSOrderedSame == [[w string] caseInsensitiveCompare:@"from"]) {
				p = sppFrom;
				isKeyword = YES;
			} else { 
				if (desc != nil && [desc fieldWithName:[w string]] == nil) underline = YES;
			}
		} else if (p == sppFrom) {
			if (NSOrderedSame == [[w string] caseInsensitiveCompare:@"where"]) {
				p = sppWhere;
				isKeyword = YES;
			} else if (desc == nil) {
				underline = YES;
			}
		} else if (p == sppWhere || p == sppWhereLiteral || p == sppWhereAndOr) {
			if (NSOrderedSame == [[w string] caseInsensitiveCompare:@"not"]) {
				p = sppWhereNot;
				isKeyword = YES;
			} else if ((NSOrderedSame == [[w string] caseInsensitiveCompare:@"and"]) || (NSOrderedSame == [[w string] caseInsensitiveCompare:@"or"])) {
				p = sppWhereAndOr;
				isKeyword = YES;
			} else {
				p = sppWhereField;
				if (desc != nil && [desc fieldWithName:[w string]] == nil) underline = YES;
			}
		} else if (p == sppWhereNot) {
			p = sppWhereField;
			if (desc != nil && [desc fieldWithName:[w string]] == nil) underline = YES;
		} else if (p == sppWhereField) {
			p = sppWhereOperator;
			isKeyword = YES;
		} else if (p == sppWhereOperator) {
			p = sppWhereLiteral;
		} else if (p == sppWhereLiteral) {
			p = sppWhere;
		}
		[w addAttributes:underline ? underlined : noUnderline range:NSMakeRange(0, [w length])];
		[w addAttribute:NSForegroundColorAttributeName value:isKeyword ? keywordColor : fieldColor range:NSMakeRange(0, [w length])];
	}
}

- (IBAction)describeItemClicked:(id)sender {
	id selectedItem = [describeList itemAtRow:[describeList selectedRow]];
	if ([selectedItem isKindOfClass:[NSString class]])
	{
		ZKDescribeSObject * d = [descDataSource describe:selectedItem];
		NSMutableString * query = [NSMutableString string];
		[query appendString:@"select"];
		ZKDescribeField * f;
		NSEnumerator *e = [[d fields] objectEnumerator];
		while (f = [e nextObject]) 
			[query appendFormat:@" %@,", [f name]];
		NSRange lastChar = {[query length]-1, 1};
		[query deleteCharactersInRange:lastChar];
		[query appendFormat:@" from %@", selectedItem];
		[self setSoqlString:query];
	}
}

- (IBAction)filterSObjectListView:(id)sender {
	[descDataSource setFilter:[sender stringValue]];
}

- (void)setRowsLoadedStatusText:(ZKQueryResult *)qr {
	[self setStatusText:[NSString stringWithFormat:@"loaded %d of %d total rows", [[qr records] count], [qr size]]];
}

- (void)permformQuery:(BOOL)useQueryAll {
	[self updateProgress:YES];
	[queryListController addQuery:[self soqlString]];
	[[NSUserDefaults standardUserDefaults] setObject:[self soqlString] forKey:@"soql"];
	@try {
		NSString *query = [self soqlString];
		ZKQueryResult * qr = useQueryAll ? [sforce queryAll:query] : [sforce query:query];
		if ([qr size] > 0) {
			if ([[qr records] count] == 0) {
				[self setStatusText:[NSString stringWithFormat:@"Count query result is %d rows", [qr size]]];
			} else {
				[rootResults setQueryResult:qr];
				[childResults setQueryResult:nil];
				[self setRowsLoadedStatusText:qr];
			}
		} else {
			[self setStatusText:@"Query returned 0 rows"];
			[rootResults setQueryResult:nil];
			[childResults setQueryResult:nil];
		}
	}
	@catch (ZKSoapException *ex)
	{
		[self updateProgress:NO];
		NSAlert * a = [NSAlert alertWithMessageText:[ex reason] defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Query failed"];
		[a runModal];
	}
	[self updateProgress:NO];
}

- (IBAction)queryResultDoubleClicked:(id)sender {
	int cc = [sender clickedColumn];
	if (cc > -1) {
		NSTableColumn *c = [[rootTableView tableColumns] objectAtIndex:cc];
		NSObject *val = [[[[rootResults queryResult]  records] objectAtIndex:[sender clickedRow]] fieldValue:[c identifier]];
		if ([val isKindOfClass:[ZKQueryResult class]]) {
			ZKQueryResult *qr = (ZKQueryResult *)val;
			[self openChildTableView];
			[childResults setQueryResult:qr];
		} else if ([[rootResults wrapper] allowEdit:c]) {
			[rootTableView editColumn:[sender clickedColumn] row:[sender clickedRow] withEvent:nil select:YES]; 
		}
	}
}

- (IBAction)saveQueryResults:(id)sender {
	ResultsSaver *saver = [[[ResultsSaver alloc] initWithResults:rootResults client:sforce] autorelease];
	[saver save:myWindow];
}

- (IBAction)executeQuery:(id)sender {
	[self permformQuery:NO];
}	

- (IBAction)executeQueryAll:(id)sender {
	[self permformQuery:YES];
}

- (BOOL)canQueryMore {
	return [[rootResults queryResult] queryLocator] != nil;
}

- (BOOL)hasSelectedForDelete {	
	return [[rootResults wrapper] hasCheckedRows];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	if (object == rootResults) {
		[self willChangeValueForKey:@"hasSelectedForDelete"];
		[self didChangeValueForKey:@"hasSelectedForDelete"];
	}
}

- (IBAction)deleteCheckedRows:(id)sender {
	BulkDelete *bd = [[BulkDelete alloc] initWithClient:sforce];
	[bd performBulkDelete:rootResults  window:myWindow];
}

- (void)dataChangedOnObject:(ZKSObject *)anObject field:(NSString *)fieldName value:(id)newValue {
	id existingVal = [anObject fieldValue:fieldName];
	if ([existingVal isEqualToString:newValue]) return;
	if (existingVal == nil && [newValue length] == 0) return;
	[self setStatusText:[NSString stringWithFormat:@"Updating field %@ on row with Id %@", fieldName, [anObject id]]];
	ZKSObject *update = [ZKSObject withTypeAndId:[anObject type] sfId:[anObject id]];
	[update setFieldValue:newValue field:fieldName];
	ZKSaveResult *sr = [[sforce update:[NSArray arrayWithObject:update]] objectAtIndex:0];
	if ([sr success]) {
		[self setStatusText:[NSString stringWithFormat:@"Updated field %@ on row with Id %@", fieldName, [anObject id]]];
		[anObject setFieldValue:newValue field:fieldName];
	} else {
		NSAlert * a = [NSAlert alertWithMessageText:[sr message] defaultButton:@"Cancel" alternateButton:nil otherButton:nil informativeTextWithFormat:[sr statusCode]];
		[a runModal];
	}
}

- (IBAction)queryMore:(id)sender {
	[self updateProgress:YES];
	ZKQueryResult * next = [sforce queryMore:[[rootResults queryResult] queryLocator]];
	NSMutableArray *allRecs = [NSMutableArray arrayWithArray:[[rootResults queryResult] records]];
	[allRecs addObjectsFromArray:[next records]];
	ZKQueryResult * total = [[ZKQueryResult alloc] initWithRecords:allRecs size:[next size] done:[next done] queryLocator:[next queryLocator]];
	[rootResults setQueryResult:total];
	[self setRowsLoadedStatusText:total];
	[self updateProgress:NO];
	[total release];
}

- (DescribeListDataSource *)describeDataSource {
	return descDataSource;
}

- (NSArray *)SObjects {
	return [descDataSource SObjects];
}

- (ZKDescribeSObject *)selectedSObject {
	id selectedItem = [describeList itemAtRow:[describeList selectedRow]];
	if ([selectedItem isKindOfClass:[NSString class]]) {
		// sobject
		return [descDataSource describe:selectedItem];
	} else {
		// field
		return [selectedItem sobject];
	}
}

- (IBAction)selectedSObjectChanged:(id)sender {
	id selectedItem = [describeList itemAtRow:[describeList selectedRow]];
	NSObject<NSTableViewDataSource> *dataSource;
	if ([selectedItem isKindOfClass:[NSString class]]) {
		// sobject
		ZKDescribeSObject *desc = [descDataSource describe:selectedItem];
		dataSource = [[[SObjectDataSource alloc] initWithDescribe:desc] autorelease];
		if ([[[soqlSchemaTabs selectedTabViewItem] identifier] isEqualToString:schemaTabId])
			[schemaController setSchemaViewToSObject:desc];
	} else {
		// field
		[dataSource = [[SObjectFieldDataSource alloc] initWithDescribe:selectedItem] autorelease];
	}
	[detailsController setDataSource:dataSource];
}

- (IBAction)generateReportForSelection:(id)sender {
	ZKDescribeSObject *sobject = [self selectedSObject]; 
	if (sobject == nil) return;
	ReportDocument *d = [[ReportDocument alloc] init];
	[d makeWindowControllers];
	[d showWindows];
	[d setSObjectType:[sobject name] andDataSource:[self describeDataSource]];
}

-(NSString *)idOfSelectedRowInTableVew:(NSTableView *)tv primaryIdOnly:(BOOL)primaryIdOnly {
	int r = [tv clickedRow];
	int c = [tv clickedColumn];
	if (r >= 0 && c >= 0) {
		NSTableColumn *tc = [[tv tableColumns] objectAtIndex:c];
		if (primaryIdOnly 
			|| (![[tc identifier] hasSuffix:@"Id"]) 
			|| ([[[tv dataSource] tableView:tv objectValueForTableColumn:tc row:r] length] != 18) ) {
			tc = [tv tableColumnWithIdentifier:@"Id"];
		}
		if (tc != nil) {
			NSString *theId = [[tv dataSource] tableView:tv objectValueForTableColumn:tc row:r];
			if ([theId length] == 18) 
				return theId;
		}
	}
	return nil;
}

- (IBAction)showSelectedIdInBrowser:(NSTableView *)tv {
	NSString *theId = [self idOfSelectedRowInTableVew:tv primaryIdOnly:NO];
	if (theId == nil) return;
	NSString *retUrl = [NSString stringWithFormat:@"/%@", theId];
	[self launchSfdcBrowser:retUrl];
}

- (IBAction)showSelectedIdFronRootInBrowser:(id)sender {
	[self showSelectedIdInBrowser:rootTableView];
}

- (IBAction)showSelectedIdFronChildInBrowser:(id)sender {
	[self showSelectedIdInBrowser:childTableView];
}

- (void)deleteSelectedRowInTable:(QueryResultTable *)tr {
	NSString *theId = [self idOfSelectedRowInTableVew:[tr table] primaryIdOnly:YES];
	if (theId == nil) return;
	ZKSaveResult *sr = [[sforce delete:[NSArray arrayWithObject:theId]] objectAtIndex:0];
	if ([sr success]) {
		int r = [[tr table] clickedRow];
		[tr removeRowAtIndex:r];
		[self setRowsLoadedStatusText:[tr queryResult]];
	} else {
		NSAlert * a = [NSAlert alertWithMessageText:[sr message] defaultButton:@"Cancel" alternateButton:nil otherButton:nil informativeTextWithFormat:[sr statusCode]];
		[a runModal];
	}
}

- (IBAction)deleteSelectedRow:(id)sender {
	QueryResultTable *t = [sender tag] == 1 ? rootResults : childResults;
	[self deleteSelectedRowInTable:t];
}

// NSTabView delegate
- (void)tabView:(NSTabView *)tab didSelectTabViewItem:(NSTabViewItem *)item {
	if ([[item identifier] isEqualToString:schemaTabId]) {
		[self setSchemaViewIsActive:YES];
		[self selectedSObjectChanged:self];
	} else {
		[self setSchemaViewIsActive:NO];
	}
}

// NSSplitView delegate
- (CGFloat)splitView:(NSSplitView *)sender constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)offset {
	return proposedMin + MIN_PANE_SIZE;
}

- (CGFloat)splitView:(NSSplitView *)sender constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)offset {
	return proposedMax - MIN_PANE_SIZE;
}

- (BOOL)splitView:(NSSplitView *)sender canCollapseSubview:(NSView *)subview {
	return subview == [[childTableView superview] superview];
}

- (BOOL)splitView:(NSSplitView *)splitView shouldCollapseSubview:(NSView *)subview forDoubleClickOnDividerAtIndex:(NSInteger)dividerIndex {
	return dividerIndex == 1 && [self splitView:splitView canCollapseSubview:subview];
}

@end

