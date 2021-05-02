// Copyright (c) 2006-2015,2018,2019,2021 Simon Fell
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
#import "DetailsController.h"
#import "ZKLoginController.h"
#import "EditableQueryResultWrapper.h"
#import "QueryResultTable.h"
#import "QueryListController.h"
#import "ApexController.h"
#import <ZKSforce/ZKSforce.h>
#import "ResultsSaver.h"
#import "BulkDelete.h"
#import "SearchQueryResult.h"
#import "ZKDescribeThemeItem+ZKFindResource.h"
#import "Prefs.h"
#import "AppDelegate.h"
#import "SoqlColorizer.h"
#import "SoqlTokenizer.h"
#import "ZKTextView.h"

static NSString *soqlTabId = @"soql";
static NSString *schemaTabId = @"schema";
static NSString *apexTabId = @"Apex";

static CGFloat MIN_PANE_SIZE = 128.0f;
static NSString *KEYPATH_WINDOW_VISIBLE = @"windowVisible";

@interface Explorer ()
- (IBAction)postLogin:(id)sender;
- (void)closeLoginPanelIfOpen:(id)sender;

@property (copy) NSString *soqlString;

- (void)colorize;

- (void)collapseChildTableView;
- (void)openChildTableView;

@property (strong) NSMutableArray *selectedFields;
@property (strong) NSString *selectedObjectName;

@property (strong) NSString *previouslyColorized;
@property (strong) ZKDescribeGlobalSObject *previousColorizedDescribe;

@property (strong) ZKSforceClient *sforce;
@property (strong) SoqlTokenizer *colorizer;
@end


@implementation Explorer

@synthesize sforce, statusText, schemaViewIsActive, apiCallCountText;
@synthesize selectedObjectName, selectedFields, previouslyColorized, previousColorizedDescribe;
@synthesize isQuerying, isEditing;

+(NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
    NSSet *paths = [super keyPathsForValuesAffectingValueForKey:key];
    if ([key isEqualToString:@"canQueryMore"])
        return [paths setByAddingObjectsFromArray:@[@"rootResults.queryResult"]];
    if ([key isEqualToString:@"titleUserInfo"])
        return [paths setByAddingObjectsFromArray:@[@"sforce", @"queryFilename", @"apexFilename", @"selectedTabViewIdentifier"]];
    if ([key isEqualToString:@"hasSelectedForDelete"])
        return [paths setByAddingObjectsFromArray:@[@"rootResults.hasCheckedRows"]];
    return paths;
}

- (void)awakeFromNib {
    [myWindow setContentBorderThickness:28.0 forEdge:NSMinYEdge];     
    [myWindow setContentBorderThickness:28.0 forEdge:NSMaxYEdge];     
    myWindow.delegate = self;
    soql.enabledTextCheckingTypes = 0;
    
    soqlSchemaTabs.delegate = self;
    [soqlHeader setHeaderText:@"Query"];
    self.statusText = @"";
    
    [progress setUsesThreadedAnimation:YES];
    describeList.doubleAction = @selector(describeItemClicked:);    
    rootTableView.target = self;
    rootTableView.doubleAction = @selector(queryResultDoubleClicked:);
    self.rootResults = [[QueryResultTable alloc] initForTableView:rootTableView];
    self.rootResults.delegate = self;
    self.childResults = [[QueryResultTable alloc] initForTableView:childTableView];
    self.childResults.delegate = self;
    [self collapseChildTableView];
    
    queryListController.delegate = self;
    [queryListController addObserver:self forKeyPath:KEYPATH_WINDOW_VISIBLE options:NSKeyValueObservingOptionNew context:nil];
    [detailsController addObserver:self forKeyPath:KEYPATH_WINDOW_VISIBLE options:NSKeyValueObservingOptionNew context:nil];
    
    [self setSoqlString:[[NSUserDefaults standardUserDefaults] stringForKey:@"soql"]];
}

- (void)dealloc {
    [detailsController removeObserver:self forKeyPath:KEYPATH_WINDOW_VISIBLE];
    [queryListController removeObserver:self forKeyPath:KEYPATH_WINDOW_VISIBLE];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)windowWillClose:(NSNotification *)notification {
    [descDataSource stopBackgroundDescribe];
}

- (void)changeEditFont:(id)sender; {
    soql.textStorage.font = [sender convertFont:soql.textStorage.font];
    [NSFont setUserFixedPitchFont:soql.textStorage.font];
    [apexController changeEditFont:sender];
}

-(void)updateCallCount:(ZKSforceClient *)c {
    ZKLimitInfoHeader *h = c.lastLimitInfoHeader;
    ZKLimitInfo *api = [h limitInfoOfType:@"API REQUESTS"];
    NSString *newVal = (api == nil) ? nil : [NSString stringWithFormat:@"Org API calls %ld/%ld", (long)[api current], (long)[api limit]];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.apiCallCountText = newVal;
    });
}

- (void)collapseChildTableView {
    if (![soqlTextSplitView isSubviewCollapsed:childTableView.superview.superview]) {
        NSRect viewFrame = childTableView.superview.superview.frame;
        uncollapsedDividerPosition = viewFrame.origin.y + viewFrame.size.height;
        [soqlTextSplitView setPosition:[soqlTextSplitView maxPossiblePositionOfDividerAtIndex:1] ofDividerAtIndex:1];
    }
}

- (void)openChildTableView {
    if ([soqlTextSplitView isSubviewCollapsed:childTableView.superview.superview]) {
        CGFloat p = [soqlTextSplitView maxPossiblePositionOfDividerAtIndex:1] - MIN_PANE_SIZE;
        [soqlTextSplitView setPosition:p ofDividerAtIndex:1];
    }
}

- (IBAction)showLogin:(id)sender {
    loginController = [[ZKLoginController alloc] init];
    [loginController setClientIdFromInfoPlist];
    loginController.delegate = self;
    NSNumber *apiVersion = [[NSUserDefaults standardUserDefaults] objectForKey:@"zkApiVersion"];
    if (apiVersion != nil) {
        loginController.preferedApiVersion = apiVersion.intValue;
    }
    [loginController showLoginSheet:myWindow];
}

-(void)loginControllerLoginCancelled:(ZKLoginController *)controller {
    [myWindow close];
}

-(void)loginController:(ZKLoginController *)controller loginCompleted:(ZKSforceClient *)client {
    loginController = nil;
    [self useClient:client];
}

- (void)useClient:(ZKSforceClient *)client {
    [self closeLoginPanelIfOpen:self];
    self.sforce = client;
    self.sforce.delegate = self;
    loginController = nil;
    [self postLogin:self];
}

-(void)closeLoginPanelIfOpen:(id)sender {
    [loginController cancelLogin:sender];
}

-(BOOL)loginSheetIsOpen {
    return loginController != nil;
}

-(BOOL)isLoggedIn {
    return [sforce loggedIn];
}

-(void)launchSfdcBrowser:(NSString *)retUrl {
    NSString *returnUrl = retUrl == nil ? @"" : [NSString stringWithFormat:@"&retURL=%@", retUrl];
    NSURL *fd = [NSURL URLWithString:[NSString stringWithFormat:@"/secur/frontdoor.jsp?sid=%@%@", [self.sforce sessionId], returnUrl]
                       relativeToURL:self.sforce.serverUrl];
    [[NSWorkspace sharedWorkspace] openURL:fd];
}

- (IBAction)showInBrowser:(id)sender {
    [self launchSfdcBrowser:nil];
}

- (void)updateProgress:(BOOL)show {
    progress.doubleValue = show ? 50 : 0;
    if (show)
        [progress startAnimation:self];
    else
        [progress stopAnimation:self];
    progress.hidden = !show;
    [progress display];
}

-(ZKFailWithErrorBlock)errorHandler {
    return ^(NSError *err) {
        [self updateProgress:NO];
        [[NSAlert alertWithError:err] runModal];
        self.isEditing = NO;
        self.isQuerying = NO;
    };
}

-(void)describe:(NSString *)sobject failed:(NSError *)err {
    // describe failed after a number of attempts.
    NSAlert *a = [[NSAlert alloc] init];
    a.messageText = @"Describe API Call failled";
    a.informativeText = [NSString stringWithFormat:@"The describeSobject API call for %@ failed after multiple attempts. Detailed object information for this object will not be available. This is likely a Salesforce bug. The last error was %@", sobject, err.description];
    [a addButtonWithTitle:@"Close"];
    [a runModal];
}

- (IBAction)postLogin:(id)sender {
    [sforce currentUserInfoWithFailBlock:[self errorHandler] completeBlock:^(ZKUserInfo *userInfo) {
        NSString *msg = [NSString stringWithFormat:@"Welcome %@ (instance:%@)",
                         [userInfo fullName],
                         [self.sforce serverHostAbbriviation]];
        self.statusText = msg;
        NSString *userId = [userInfo userId];
        self->queryListController.prefsPrefix = userId;
        self->detailsController.prefsPrefix = userId;
    }];

    DescribeListDataSource *dds = [[DescribeListDataSource alloc] init];
    descDataSource = dds;
    descDataSource.delegate = self;
    self.rootResults.describer = ^ZKDescribeSObject *(NSString *type) {
        ZKDescribeSObject *o = [dds cachedDescribe:type];
        if (o == nil) {
            [dds prioritizeDescribe:type];
        }
        return o;
    };
    self.childResults.describer = self.rootResults.describer;
    [apexController setSforceClient:sforce];
    [descDataSource setSforce:sforce];
    describeList.dataSource = descDataSource;
    describeList.delegate = descDataSource;
    [describeList reloadData];

    self.colorizer = [SoqlTokenizer new];
    self.colorizer.describer = [DLDDescriber describer:descDataSource];
    self.colorizer.view = soql;
    soql.textStorage.delegate = self.colorizer;
    soql.delegate = self.colorizer;
    

    [schemaController setDescribeDataSource:descDataSource];
    [self colorize];
    [self updateProgress:NO];
    [self willChangeValueForKey:@"isLoggedIn"];
    [self didChangeValueForKey:@"isLoggedIn"];
    [self.rootResults setQueryResult:nil];
    [self.childResults setQueryResult:nil];

    [sforce describeGlobalThemeWithFailBlock:^(NSError *result) {
        [[NSAlert alertWithError:result] runModal];
    } completeBlock:^(ZKDescribeGlobalTheme *result) {
        [self willChangeValueForKey:@"SObjects"];
        [self->descDataSource setTypes:result view:self->describeList];
        [self didChangeValueForKey:@"SObjects"];
    }];
}

-(void)highlightItemInSideBar:(id)sender {
    NSLog(@"highlight Item in side bar %@", sender);
}

- (void)refreshMetadata:(id)sender {
    [sforce describeGlobalThemeWithFailBlock:^(NSError *result) {
        [[NSAlert alertWithError:result] runModal];
    } completeBlock:^(ZKDescribeGlobalTheme *result) {
        [self willChangeValueForKey:@"SObjects"];
        [self.describeDataSource refreshDescribes:result view:self->describeList];
        [self didChangeValueForKey:@"SObjects"];
    }];
}

- (void)setSoqlString:(NSString *)str {
    NSAttributedString *s = [[NSAttributedString alloc]
                             initWithString:str
                             attributes:@{
                                          NSForegroundColorAttributeName: [NSColor textColor]
                                                                         }];
    [soql.textStorage setAttributedString:s];
    soql.textStorage.font = [(AppDelegate*)[NSApp delegate] editFont];
    self.previouslyColorized = nil;
    self.previousColorizedDescribe = nil;
    [self colorize];
}

- (void)queryTextListView:(QueryTextListView *)listView itemClicked:(QueryTextListViewItem *)item {
    NSString *t = item.text;
    if (t == nil || t.length == 0) return;
    [self setSoqlString:t];
}

- (NSString *)soqlString {
    return soql.textStorage.string;
}

- (void)enumerateWordsInString:(NSString *)s withBlock:(void(^)(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop)) block {
    [s enumerateSubstringsInRange:NSMakeRange(0, s.length)
                          options:NSStringEnumerationByWords | NSStringEnumerationLocalized
                       usingBlock:block];
}

- (NSString *)parseEntityName:(NSString *)soqlText {
    __block NSString *entity = nil;
    __block BOOL atFrom = NO;
    [self enumerateWordsInString:soqlText withBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
        if (atFrom) {
            entity = substring;
            *stop = YES;
            
        } else if (NSOrderedSame == [substring caseInsensitiveCompare:@"from"]) {
            atFrom = YES;
        }
    }];
    return entity;
}

- (void)described:(nonnull NSArray<ZKDescribeSObject *> *)sobjects {
    [self colorize];
    NSString *msg = [NSString stringWithFormat:@"Described %lu/%lu SObjects", (unsigned long)descDataSource.describedCount, (unsigned long)descDataSource.totalCount];
    [self setStatusText:msg];
}

- (void)colorize {
    [self.colorizer color];
}

-(NSString *)removeSuffix:(NSString *)suffix from:(NSString *)src {
    if ([src hasSuffix:suffix])
        return [src substringToIndex:src.length - suffix.length];
    return src;
}

-(void)addSuffixes:(NSString *)prefix suffixes:(NSArray *)suffixes to:(NSMutableSet *)col {
    for (NSString *s in suffixes)
        [col addObject:[prefix stringByAppendingString:s]];
}

- (IBAction)describeItemClicked:(id)sender {
    if(selectedFields == nil) {
        selectedFields = [[NSMutableArray alloc] init];
    }
    ZKDescribeSObject * d;
    id selectedItem = [describeList itemAtRow:describeList.selectedRow];
    
    if ([selectedItem isKindOfClass:[ZKDescribeField class]]) {
        if (![selectedObjectName isEqualToString:((ZKDescribeGlobalSObject *)[selectedItem sobject]).name]) {
            [selectedFields removeAllObjects];
        }
        self.selectedObjectName = ((ZKDescribeGlobalSObject *)[selectedItem sobject]).name;
        if ([selectedFields containsObject:selectedItem]) {
            [selectedFields removeObject:selectedItem];
        } else {
            [selectedFields addObject:selectedItem];
        }
        
    } else {
        self.selectedObjectName = [selectedItem name];
        d = [descDataSource cachedDescribe:selectedObjectName];
        [selectedFields removeAllObjects];
        [selectedFields addObjectsFromArray:d.fields];
    }
    
    NSMutableString * query = [NSMutableString string];
    [query appendString:@"select"];
    
    NSArray *fields = [selectedFields copy];
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:PREF_QUERY_SORT_FIELDS]) {
        NSSortDescriptor *sd = [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)];
        fields = [fields sortedArrayUsingDescriptors:@[sd]];
    }
    // There's no point selecting both the compound address field,and its component parts, do one or the other.
    BOOL useComponentFields = [[NSUserDefaults standardUserDefaults] boolForKey:PREF_SKIP_ADDRESS_FIELDS];
    if (useComponentFields) {
            // easy case, just skip the compound fields
        fields = [fields filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"not (type in { 'address','location'})"]];
    } else {
        // more work, calculate set of the component field names to skip, based on the name of the compound Field + the standard trailers
        NSMutableSet *fieldsToSkip = [NSMutableSet set];
        for (ZKDescribeField * f in [fields filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"type=='address' || type=='location'"]]) {
            NSArray *lsuffixes = @[@"Longitude", @"Latitude"];
            NSArray *lcsuffixes= @[@"__Longitude__s", @"__Latitude__s"];
            NSArray *asuffixes = @[@"City", @"Country", @"CountryCode", @"State", @"StateCode", @"PostalCode", @"Street"];
            NSString *prefix = f.name;
            prefix = [self removeSuffix:@"__c" from:prefix];
            prefix = [self removeSuffix:@"Address" from:prefix];
            [self addSuffixes:prefix suffixes:lsuffixes to:fieldsToSkip];
            if ([f.type isEqualToString:@"address"])
                [self addSuffixes:prefix suffixes:asuffixes to:fieldsToSkip];
            if (f.custom)
                [self addSuffixes:prefix suffixes:lcsuffixes to:fieldsToSkip];
        }
        fields = [fields filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"not (name in %@)", fieldsToSkip]];
    }

    for (ZKDescribeField *f in fields)
        [query appendFormat:@" %@,", f.name];
    NSRange lastChar = {query.length-1, 1};
    [query deleteCharactersInRange:lastChar];
    [query appendFormat:@" from %@", selectedObjectName];
    [self setSoqlString:query];
}

- (IBAction)filterSObjectListView:(id)sender {
    [descDataSource setFilter:[sender stringValue]];
}

- (void)setRowsLoadedStatusText:(ZKQueryResult *)qr timing:(NSString *)time {
    self.statusText = [NSString stringWithFormat:@"loaded %ld of %ld total rows %@", (unsigned long)[qr records].count, (long)[qr size], time];
}

- (NSString *)execTimeSince:(NSDate *)started {
    return [NSString stringWithFormat:@"(in %.0f ms)", [[NSDate date] timeIntervalSinceDate:started] * 1000];
}

- (void)permformQuery:(BOOL)useQueryAll {
    [self updateProgress:YES];
    self.isQuerying = YES;
    [queryListController addQuery:[self soqlString]];
    [[NSUserDefaults standardUserDefaults] setObject:[self soqlString] forKey:@"soql"];

    NSString *query = [[self soqlString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSDate *started = [NSDate date];
    ZKCompleteQueryResultBlock cb = ^(ZKQueryResult *qr) {
        [self updateProgress:NO];
        self.isQuerying = NO;
        NSString *time = [self execTimeSince:started];
        if ([qr size] > 0) {
            if ([qr records].count == 0) {
                self.statusText = [NSString stringWithFormat:@"Count query result is %ld rows %@", (long)[qr size], time];
            } else {
                self.rootResults.queryResult = qr;
                [self.childResults setQueryResult:nil];
                [self setRowsLoadedStatusText:qr timing:time];
            }
        } else {
            self.statusText = [NSString stringWithFormat:@"Query returned 0 rows %@", time];
            [self.rootResults setQueryResult:nil];
            [self.childResults setQueryResult:nil];
        }
    };
    if ([query.lowercaseString hasPrefix:@"find "]) {
        [sforce search:query failBlock:[self errorHandler] completeBlock:^(ZKSearchResult *searchResult) {
            ZKQueryResult *qr = [SearchQueryResult searchQueryResults:searchResult];
            cb(qr);
        }];
    } else if (useQueryAll) {
        [sforce queryAll:query failBlock:[self errorHandler] completeBlock:cb];
    } else {
        [sforce query:query failBlock:[self errorHandler] completeBlock:cb];
    }
}

- (IBAction)queryResultDoubleClicked:(id)sender {
    NSInteger cc = [sender clickedColumn];
    NSInteger cr = [sender clickedRow];
    if (cc > -1 && cr > -1) {
        NSTableColumn *c = rootTableView.tableColumns[cc];
        NSObject *val = [[self.rootResults.queryResult records][[sender clickedRow]] fieldValue:c.identifier];
        if ([val isKindOfClass:[ZKQueryResult class]]) {
            ZKQueryResult *qr = (ZKQueryResult *)val;
            [self openChildTableView];
            self.childResults.queryResult = qr;
        } else {
            [rootTableView editColumn:[sender clickedColumn] row:[sender clickedRow] withEvent:nil select:YES]; 
        }
    }
}

-(NSString *)titleUserInfo {
    NSString *doc = @"SoqlX";
    if ([self.selectedTabViewIdentifier isEqualToString:soqlTabId] && self.queryFilename != nil) {
        doc = self.queryFilename.lastPathComponent;
        doc = [doc substringToIndex:doc.length - self.queryFilename.pathExtension.length - 1];
    } else if ([self.selectedTabViewIdentifier isEqualToString:apexTabId] && self.apexFilename != nil) {
        doc = self.apexFilename.lastPathComponent;
        doc = [doc substringToIndex:doc.length - self.apexFilename.pathExtension.length - 1];
    }
    if (self.sforce == nil) {
        return doc;
    }
    // Regular soap login will always have the cachedUserInfo from Login Result.
    // SID based logins, explictly call cachedUserInfo to validate the sid.
    // So by this point there's always a cached user info we can use.
    NSString *user = [NSString stringWithFormat:@"%@ : %@ (%@ on %@)",
        doc,
        [[sforce cachedUserInfo] fullName],
        [sforce cachedUserInfo].userName,
        [sforce serverHostAbbriviation]];
    
    return user;
}

-(NSError *)loadQuery:(NSURL *)url {
    NSError *err = nil;
    NSString *soql = [[NSString alloc] initWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&err];
    if (err != nil) {
        self.queryFilename = nil;
    } else {
        self.queryFilename = url;
        self.soqlString = soql;
        [self.soqlSchemaApexSelector selectSegmentWithTag:0];
        [soqlSchemaTabs selectTabViewItemWithIdentifier:soqlTabId];
    }
    return err;
}

-(NSError *)loadApex:(NSURL *)url {
    NSError *err = nil;
    NSString *apex = [[NSString alloc] initWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&err];
    if (err != nil) {
        self.apexFilename = nil;
    } else {
        self.apexFilename = url;
        apexController.apex = apex;
        [self.soqlSchemaApexSelector selectSegmentWithTag:2];
        [soqlSchemaTabs selectTabViewItemWithIdentifier:apexTabId];
    }
    return err;
}

-(NSError *)loadFromURLType:(NSURL *)url {
    NSString *type;
    NSError *error;
    if ([url getResourceValue:&type forKey:NSURLTypeIdentifierKey error:&error]) {
        if ([[NSWorkspace sharedWorkspace] type:type conformsToType:@"com.pocketsoap.anon.apex"]) {
            return [self loadApex:url];
        }
    }
    return [self loadQuery:url];
}

-(void)load:(NSURL *)url {
    NSError *err = [self loadFromURLType:url];
    if (err != nil) {
        NSAlert *alert = [NSAlert alertWithError:err];
        [alert runModal];
    }
}

// Called via "Open..." Menu item
-(void)open:(id)sender {
    NSOpenPanel *o = [NSOpenPanel openPanel];
    o.allowsOtherFileTypes = YES;
    o.allowedFileTypes = @[@"com.pocketsoap.soql", @"com.pocketsoap.anon.apex"];
    [o beginSheetModalForWindow:myWindow completionHandler:^(NSModalResponse result) {
        if (result != NSModalResponseOK) {
            return;
        }
        NSError *err = [self loadFromURLType:o.URL];
        if (err != nil) {
            [o orderOut:nil];
            NSAlert *alert = [NSAlert alertWithError:err];
            [alert beginSheetModalForWindow:self->myWindow completionHandler:^(NSModalResponse returnCode) {}];
        }
    }];
}

-(void)saveQuery:(NSSavePanel *)s {
    if (self.queryFilename == nil) {
        s.nameFieldStringValue = @"query.soql";
    } else {
        s.nameFieldStringValue = self.queryFilename.lastPathComponent;
    }
    s.allowedFileTypes= @[@"com.pocketsoap.soql"];
    [s beginSheetModalForWindow:myWindow completionHandler:^(NSModalResponse result) {
        if (result != NSModalResponseOK) {
            return;
        }
        NSError *err = nil;
        if ([[self soqlString] writeToURL:s.URL atomically:YES encoding:NSUTF8StringEncoding error:&err]) {
            self.queryFilename = s.URL;
        } else {
            [s orderOut:nil];
            NSAlert *alert = [NSAlert alertWithError:err];
            [alert beginSheetModalForWindow:self->myWindow completionHandler:^(NSModalResponse returnCode) {}];
        }
    }];
}

-(void)saveApex:(NSSavePanel *)s {
    if (self.apexFilename == nil) {
        s.nameFieldStringValue = @"apex.aapx";
    } else {
        s.nameFieldStringValue = self.apexFilename.lastPathComponent;
    }
    s.allowedFileTypes = @[@"com.pocketsoap.anon.apex"];
    [s beginSheetModalForWindow:myWindow completionHandler:^(NSModalResponse result) {
        if (result != NSModalResponseOK) {
            return;
        }
        NSError *err = nil;
        if ([self->apexController.apex writeToURL:s.URL atomically:YES encoding:NSUTF8StringEncoding error:&err]) {
            self.apexFilename = s.URL;
        } else {
            [s orderOut:nil];
            NSAlert *alert = [NSAlert alertWithError:err];
            [alert beginSheetModalForWindow:self->myWindow completionHandler:^(NSModalResponse returnCode) {}];
        }
    }];
}

// Called via "Save" Menu item
-(void)save:(id)sender {
    NSSavePanel *s = [NSSavePanel savePanel];
    s.allowsOtherFileTypes = YES;
    s.extensionHidden = NO;
    s.canSelectHiddenExtension = YES;

    if ([soqlSchemaTabs.selectedTabViewItem.identifier isEqualToString:apexTabId]) {
        [self saveApex:s];
        return;
    }
    [self saveQuery:s];
}

// Called via "Save Query Results" Menu item
-(void)saveQueryResults:(id)sender {
    ResultsSaver *saver = [[ResultsSaver alloc] initWithResults:self.rootResults client:sforce];
    [saver save:myWindow];
}

// this is called by the menu to see if items should be enabled. This is an addition to the
// check that the target implements the selector.
-(BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)i {
    SEL theAction = [i action];
    if (theAction == @selector(save:)) {
        return ![self schemaViewIsActive];
    }
    if (theAction == @selector(saveQueryResults:)) {
        return (self.rootResults.queryResult.size > 0) && ![self schemaViewIsActive];
    }
    if (theAction == @selector(executeQuery:)) {
        return [self isLoggedIn];
    }
    if (theAction == @selector(executeQueryAll:)) {
        return [self isLoggedIn];
    }
    if (theAction == @selector(queryMore:)) {
        return [self canQueryMore];
    }
    return YES;
}

- (IBAction)executeQuery:(id)sender {
    [self permformQuery:NO];
}    

- (IBAction)executeQueryAll:(id)sender {
    [self permformQuery:YES];
}

- (BOOL)canQueryMore {
    return [self.rootResults.queryResult queryLocator] != nil;
}

- (BOOL)hasSelectedForDelete {    
    return self.rootResults.hasCheckedRows;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == detailsController) {
        [self.detailsRecentSelector setSelected:[change[NSKeyValueChangeNewKey] boolValue] forSegment:0];
    } else if (object == queryListController) {
        [self.detailsRecentSelector setSelected:[change[NSKeyValueChangeNewKey] boolValue] forSegment:1];
    }
}

- (IBAction)updateDetailsRecentSelection:(id)sender {
    detailsController.windowVisible = [sender isSelectedForSegment:0];
    queryListController.windowVisible = [sender isSelectedForSegment:1];
}

- (IBAction)deleteCheckedRows:(id)sender {
    BulkDelete *bd = [[BulkDelete alloc] initWithClient:sforce];
    [bd performBulkDelete:self.rootResults window:myWindow];
}

- (void)dataChangedOnObject:(ZKSObject *)anObject field:(NSString *)fieldName value:(id)newValue {
    id existingVal = [anObject fieldValue:fieldName];
    if ([existingVal isEqualToString:newValue]) return;
    if (existingVal == nil && [newValue length] == 0) return;
    self.statusText = [NSString stringWithFormat:@"Updating field %@ on row with Id %@", fieldName, [anObject id]];
    ZKSObject *update = [ZKSObject withTypeAndId:[anObject type] sfId:[anObject id]];
    [update setFieldValue:newValue field:fieldName];
    [self updateProgress:YES];
    self.isEditing = YES;
    [sforce update:@[update] failBlock:[self errorHandler] completeBlock:^(NSArray *result) {
        ZKSaveResult *sr = result[0];
        [self updateProgress:NO];
        self.isEditing = NO;
        if (sr.success) {
            self.statusText = [NSString stringWithFormat:@"Updated field %@ on row with Id %@", fieldName, [anObject id]];
            [anObject setFieldValue:newValue field:fieldName];
            [self->rootTableView reloadData];
            [self->childTableView reloadData];
        } else {
            NSAlert *a = [[NSAlert alloc] init];
            a.messageText = sr.message;
            a.informativeText = sr.statusCode;
            [a runModal];
        }
    }];
}

- (IBAction)queryMore:(id)sender {
    [self updateProgress:YES];
    self.isQuerying = YES;
    NSDate *started = [NSDate date];
    [sforce queryMore:[self.rootResults.queryResult queryLocator]
            failBlock:[self errorHandler]
        completeBlock:^(ZKQueryResult *next) {
            NSString *execTime = [self execTimeSince:started];
            NSMutableArray *allRecs = [NSMutableArray arrayWithArray:[self.rootResults.queryResult records]];
            [allRecs addObjectsFromArray:[next records]];
            ZKQueryResult * total = [[ZKQueryResult alloc] initWithRecords:allRecs size:[next size] done:[next done] queryLocator:[next queryLocator]];
            self.rootResults.queryResult = total;
            [self setRowsLoadedStatusText:total timing:execTime];
            [self updateProgress:NO];
            self.isQuerying = NO;
        }];
}

- (DescribeListDataSource *)describeDataSource {
    return descDataSource;
}

- (NSArray *)SObjects {
    return [descDataSource SObjects];
}

// When the user selected an sobject we don't have a describe for, we'll do a describe in the background
// then re-update the UI/data sources.
-(void)asyncSelectedSObjectChanged:(NSString *)sobjectType {
    [self updateProgress:YES];
    [detailsController setDataSource:nil];
    NSInteger selectedRow = describeList.selectedRow;
    [self->descDataSource describe:sobjectType
                         failBlock:[self errorHandler]
                     completeBlock:^(ZKDescribeSObject *result) {
                        [self updateProgress:NO];
                        // the describe completed, and this item is still selected update it.
                        if (selectedRow == self->describeList.selectedRow) {
                            [self selectedSObjectChanged:self];
                        }
                     }];
}

- (IBAction)selectedSObjectChanged:(id)sender {
    id selectedItem = [describeList itemAtRow:describeList.selectedRow];
    DetailDataSource *dataSource = nil;
    if ([selectedItem isKindOfClass:[ZKDescribeGlobalSObject class]]) {
        // sobject
        if (![descDataSource hasDescribe:[selectedItem name]]) {
            [self asyncSelectedSObjectChanged:[selectedItem name]];
            return;
        }
        ZKDescribeSObject *desc = [descDataSource cachedDescribe:[selectedItem name]];
        dataSource = [[SObjectDataSource alloc] initWithDescribe:desc];
        [detailsController setIcon:[descDataSource iconForType:[selectedItem name]]];
        if (self.schemaViewIsActive) {
            [schemaController setSchemaViewToSObject:desc];
        }
    } else {
        // field
        dataSource = [[SObjectFieldDataSource alloc] initWithDescribe:selectedItem];
        [detailsController setIcon:nil];
    }
    [detailsController setDataSource:dataSource];
}

- (NSString *)selectedSObjectName {
    id selectedItem = [describeList itemAtRow:describeList.selectedRow];
    if ([selectedItem isKindOfClass:[NSString class]]) {
        // sobject name
        return selectedItem;
        
    } else if ([selectedItem isKindOfClass:[ZKDescribeGlobalSObject class]]) {
        // sobject desc
        return [selectedItem name];
        
    } else if ([selectedItem isKindOfClass:[ZKDescribeField class]]) {
        // field
        return ((ZKDescribeField *)selectedItem).sobject.name;
    }
    // unknown
    NSLog(@"selected item from describeList of unexpected type %@ %@", selectedItem, [selectedItem class]);
    return selectedItem;
}

- (IBAction)generateReportForSelection:(id)sender {
    NSString *sobjectName = [self selectedSObjectName];
    if (sobjectName == nil) return;
    ReportDocument *d = [[ReportDocument alloc] init];
    [d makeWindowControllers];
    [d showWindows];
    [d setSObjectType:sobjectName andDataSource:[self describeDataSource]];
}

-(NSString *)idOfSelectedRowInTableVew:(NSTableView *)tv primaryIdOnly:(BOOL)primaryIdOnly {
    NSInteger r = tv.clickedRow;
    NSInteger c = tv.clickedColumn;
    if (r >= 0 && c >= 0) {
        NSTableColumn *tc = tv.tableColumns[c];
        if (primaryIdOnly 
            || (![tc.identifier hasSuffix:@"Id"]) 
            || ([[tv.dataSource tableView:tv objectValueForTableColumn:tc row:r] length] != 18) ) {
            tc = [tv tableColumnWithIdentifier:@"Id"];
        }
        if (tc != nil) {
            NSString *theId = [tv.dataSource tableView:tv objectValueForTableColumn:tc row:r];
            if (theId.length == 18) 
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

// NSTabView delegate
- (void)tabView:(NSTabView *)tab didSelectTabViewItem:(NSTabViewItem *)item {
    if ([item.identifier isEqualToString:schemaTabId]) {
        [self setSchemaViewIsActive:YES];
        [self selectedSObjectChanged:self];
    } else {
        [self setSchemaViewIsActive:NO];
    }
    self.selectedTabViewIdentifier = item.identifier;
}

// NSSplitView delegate
- (CGFloat)splitView:(NSSplitView *)sender constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)offset {
    return proposedMin + MIN_PANE_SIZE;
}

- (CGFloat)splitView:(NSSplitView *)sender constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)offset {
    return proposedMax - MIN_PANE_SIZE;
}

- (BOOL)splitView:(NSSplitView *)sender canCollapseSubview:(NSView *)subview {
    return subview == childTableView.superview.superview;
}

- (BOOL)splitView:(NSSplitView *)splitView shouldCollapseSubview:(NSView *)subview forDoubleClickOnDividerAtIndex:(NSInteger)dividerIndex {
    return dividerIndex == 1 && [self splitView:splitView canCollapseSubview:subview];
}

// ZKBaseClientDelegate
-(void)client:(ZKBaseClient *)client
  sentRequest:(NSString *)payload
        named:(NSString *)callName
           to:(NSURL *)destination
 withResponse:(ZKElement *)response
        error:(NSError *)error
           in:(NSTimeInterval)time {

    [self updateCallCount:(ZKSforceClient *)client];
}

@end

