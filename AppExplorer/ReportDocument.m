// Copyright (c) 2007,2012,2014 Simon Fell
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

#import "ReportDocument.h"
#import "DataSources.h"
#import "SchemaView.h"
#import "SchemaProtocol.h"
#import "ZKPicklistEntry.h"
#import "ZKChildRelationship.h"
#import "SObjectBox.h"
#import "ZKDescribe_Reporting.h"
#import "Prefs.h"

@implementation ReportDocument

@synthesize enabledButtons;

- (void)awakeFromNib {
	[progress setUsesThreadedAnimation:YES];
	[self setEnabledButtons:NO];
}

- (void)dealloc {
	[sobjectType release];
	[super dealloc];
}

- (void)windowControllerDidLoadNib:(NSWindowController *)windowController {
	[[windowController window] setContentBorderThickness:28.0 forEdge:NSMinYEdge]; 	
	[webview setUIDelegate:self];
}

// WebKit delegate for context menu items
- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems {
	return [NSArray array];
}

- (void)describeWithProgress:(DescribeListDataSource *)dataSource {
	[self setDescribesDone:0];
	if (![dataSource hasDescribe:sobjectType]) 
		[self setTotalObjects:[[dataSource SObjects] count]];
	[tabview selectTabViewItemWithIdentifier:@"progress"];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^{
        ZKDescribeSObject *desc = [dataSource describe:sobjectType];
        NSSet *allTypes = [desc namesOfAllReferencedObjects];
        int total = [allTypes count] + 1;
        int done = 1;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setTotalObjects:total];
            [self setDescribesDone:done];
        });
        for (NSString *t in allTypes) {
            [dataSource describe:t];
            done++;
            dispatch_async(dispatch_get_main_queue(), ^{
                [self setDescribesDone:done];
            });
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [self renderReportFromDataSource:dataSource];
        });
    });
}

-(void)renderFieldTable:(NSMutableString *)s sobject:(ZKDescribeSObject *)desc {
	NSString *blueKey = [[NSBundle mainBundle] pathForResource:@"key_b" ofType:@"png"];
	NSString *redKey  = [[NSBundle mainBundle] pathForResource:@"key_r" ofType:@"png"];

	[s appendString:@"<table cellspacing='0' cellpadding='0'><tr><th colspan='2'>Field</th><th>Label</th><th>Type</th><th>Properties</th><tr>"];
    NSArray *fields = [desc fields];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:PREF_SORTED_FIELD_LIST])
        fields = [fields sortedArrayUsingDescriptors:[NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)]]];
    
	for (ZKDescribeField *f in fields) {
		[s appendString:@"<tr><td colspan='2'>"];
		if ([[f name] isEqualToString:@"Id"])
			[s appendFormat:@"<img src='file://%@' alt='Primary Key'>", redKey];
		if ([f externalId])
			[s appendFormat:@"<img src='file://%@' alt='External Id'>", blueKey];
		[s appendFormat:@"%@</td><td>%@</td>", [f name], [f label]];
		[s appendFormat:@"<td>%@</td>", [f descriptiveType]];
		[s appendFormat:@"<td class='properties'>%@</td>", [f properties]];
		[s appendString:@"</tr>"];
		if ([[f calculatedFormula] length] > 0) {
			[s appendFormat:@"<tr><td class='indent'>&nbsp;</td><td colspan='4'>Formula : %@</td></tr>", [f calculatedFormula]];
		} else if ([[f defaultValueFormula] length] > 0) {
			[s appendFormat:@"<tr><td class='indent'>&nbsp;</td><td colspan='4'>Default Value Forumula: %@</td></tr>", [f defaultValueFormula]];
		}
		if ([[f inlineHelpText] length] > 0) {
			[s appendFormat:@"<tr><td class='indent'>&nbsp;</td><td colspan='4'>HelpText: %@</td></tr>", [f inlineHelpText]];
		}
	}
    [s appendString:@"</table>"];
}

-(void)renderRelationships:(NSMutableString *)s sobject:(ZKDescribeSObject *)desc {
	NSArray *cr = [desc childRelationships];
	if ([cr count] == 0) return;
	[s appendFormat:@"<h2>Relationships to %@</h2><table cellspacing='0' cellpadding='0'><tr><th>Object / Field</th><th>Relationship Name</th><th>Cascade Delete</th></tr>", [desc name]];
	for (ZKChildRelationship *r in cr) {
		[s appendFormat:@"<tr><td>%@.%@</td>", [r childSObject], [r field]];
		[s appendFormat:@"<td>%@</td>", [r relationshipName] == nil ? @"" : [r relationshipName]];
		[s appendFormat:@"<td>%@</td>", [r cascadeDelete] ? @"Yes" : @""];
		[s appendString:@"</tr>"];
	}
    [s appendString:@"</table>"];
}

- (void)setSObjectType:(NSString *)type andDataSource:(DescribeListDataSource *)newDataSource {
	[sobjectType autorelease];
	sobjectType = [type copy];
    if (![newDataSource hasAllDescribesRelatedTo:type]) {
		[self describeWithProgress:newDataSource];
	} else {
        [self renderReportFromDataSource:newDataSource];
    }
}

- (void)renderReportFromDataSource:(DescribeListDataSource *)newDataSource {
	[schemaView setDescribesDataSource:newDataSource];
	[[schemaView centralBox] setViewMode:vmAllFields];
	[schemaView setCentralSObject:[newDataSource describe:sobjectType]];
	NSRect bounds = [schemaView bounds];
	
	NSRect offscreenRect = NSMakeRect(0.0, 0.0, bounds.size.width - 40.0, bounds.size.height);
	NSBitmapImageRep* offscreenRep = nil;
	offscreenRep = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nil
	                        pixelsWide:offscreenRect.size.width 
	                        pixelsHigh:offscreenRect.size.height 
	                        bitsPerSample:8 
	                        samplesPerPixel:4 
	                        hasAlpha:YES 
	                        isPlanar:NO 
	                        colorSpaceName:NSCalibratedRGBColorSpace 
	                        bitmapFormat:0 
	                        bytesPerRow:(4 * offscreenRect.size.width) 
                            bitsPerPixel:32] autorelease];

	[NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext setCurrentContext:[NSGraphicsContext 
	                        graphicsContextWithBitmapImageRep:offscreenRep]];

	// Draw your content...
	[schemaView setNeedsFullRedraw:YES];
	[schemaView drawRect:offscreenRect];
	[NSGraphicsContext restoreGraphicsState];

	NSData *data = [offscreenRep TIFFRepresentation];
	[SchemaProtocol setData:data];
	[tabview selectTabViewItemWithIdentifier:@"report"];
	
	NSString *cssPath = [[NSBundle mainBundle] pathForResource:@"report" ofType:@"css"];

	NSMutableString *s = [NSMutableString stringWithCapacity:1024*6];
	[s appendFormat:@"<html><head><title>%@</title>", [self displayName]];
	[s appendFormat:@"<link rel='stylesheet' type='text/css' href='file://%@'>", cssPath];
	[s appendString:@"</head><body>"];
	[s appendFormat:@"<h1>%@</h1>", [self displayName]];
	[s appendString:@"<hr/>"];
	[s appendFormat:@"<img src='schema://%@'/>", sobjectType];

	ZKDescribeSObject *sobject = [newDataSource describe:sobjectType];
	[self renderFieldTable:s sobject:sobject];
	[self renderRelationships:s sobject:sobject];
	
    [s appendString:@"</body></html>"];
	[[webview mainFrame] loadHTMLString:s baseURL:nil];
	[[self windowControllers] makeObjectsPerformSelector:@selector(synchronizeWindowTitleWithDocumentName)];
	[self setEnabledButtons:YES];
}

- (NSString *)windowNibName {
	return @"ReportDocument";
}

- (NSString *)name {
	return sobjectType;
}

- (NSString *)displayName {
	if (sobjectType == nil) return @"";
	return [NSString stringWithFormat:@"%@ Schema Report", sobjectType];
}

- (int)totalObjects {
	return totalObjects;
}

- (void)setTotalObjects:(int)newTotalObjects {
	totalObjects = newTotalObjects;
	[progress setMaxValue:totalObjects];
	[progress display];
}

- (int)describesDone {
	return describesDone;
}

- (void)setDescribesDone:(int)newDescribesDone {
	describesDone = newDescribesDone;
	[progress setDoubleValue:describesDone];
	[progress display];
}

- (IBAction)print:(id)sender {
	[[[[webview mainFrame] frameView] documentView] print:sender];
}

- (IBAction)saveAsPdf:(id)sender {
	NSSavePanel *sp = [NSSavePanel savePanel];
    [sp setAllowedFileTypes:[NSArray arrayWithObject:@"pdf"]];
	[sp setTitle:@"Save Schema Report"];
	NSWindow *window = [[[self windowControllers] objectAtIndex:0] window];
    [sp beginSheetModalForWindow:window completionHandler:^(NSInteger result) {
        [self savePanelDidEnd:sp returnCode:result contextInfo:nil];
    }];
}

- (void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void  *)contextInfo {
	if (NSFileHandlingPanelOKButton == returnCode) {
		NSView *docView = [[[webview mainFrame] frameView] documentView];
		NSData *pdf =  [docView dataWithPDFInsideRect:[docView bounds]];
	    [pdf writeToURL:[sheet URL] atomically:YES];
	}
}

@end
