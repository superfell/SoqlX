#import "ReportDocument.h"
#import "DataSources.h"
#import "SchemaView.h"
#import "SchemaProtocol.h"
#import "ZKDescribeSObject.h"
#import "ZKDescribeField.h"
#import "ZKPicklistEntry.h"
#import "ZKChildRelationship.h"
#import "SObjectBox.h"

@interface ZKDescribeSObject (Reporting)
- (NSSet *)namesOfAllReferencedObjects;
@end

@interface ZKDescribeField (Reporting)
- (NSString *)descriptiveType;
- (NSString *)properties;
@end 

@implementation ZKDescribeField (Reporting)
- (NSString *)descriptiveType {
	NSString *type = [self type];
	if ([type isEqualToString:@"string"])
		return [NSString stringWithFormat:@"text(%d)", [self length]];
	if ([type isEqualToString:@"picklist"])
		return @"picklist";
	if ([type isEqualToString:@"multipicklist"])
		return @"multi select picklist";
	if ([type isEqualToString:@"combobox"])
		return @"combo box";
	if ([type isEqualToString:@"reference"])
		return @"foreign key";
	if ([type isEqualToString:@"base64"])
		return @"blob";
	if ([type isEqualToString:@"textarea"])
		return [NSString stringWithFormat:@"textarea(%d)", [self length]];
	if ([type isEqualToString:@"currency"])
		return [NSString stringWithFormat:@"currency(%d,%d)", [self precision] - [self scale], [self scale]];
	if ([type isEqualToString:@"double"])
		return [NSString stringWithFormat:@"double(%d,%d)", [self precision] - [self scale], [self scale]];
	if ([type isEqualToString:@"int"])
		return [NSString stringWithFormat:@"int(%d)", [self digits]];
	return type;
}

- (NSString *)picklistProperties {
	NSMutableString *pp = [NSMutableString string];
	ZKPicklistEntry *ple;
	NSEnumerator *e = [[self picklistValues] objectEnumerator];
	while (ple = [e nextObject]) {
		if ([ple active]) {
			if ([[ple label] isEqualToString:[ple value]])
				[pp appendFormat:@"%@<br>", [ple value]];
			else
				[pp appendFormat:@"%@ (%@)<br>", [ple label], [ple value]];
		}
	}
	return pp;
}

- (NSString *)referenceProperties {
	NSMutableString *rp = [NSMutableString string];
	NSString *type;
	NSEnumerator *e = [[self referenceTo] objectEnumerator];
	while (type = [e nextObject])
		[rp appendFormat:@"%@<br>", type];
	return rp;
}

- (NSString *)properties {
	NSString *type = [self type];
	if ([type isEqualToString:@"picklist"] || [type isEqualToString:@"multipicklist"])
		return [self picklistProperties];
	if ([type isEqualToString:@"reference"])
		return [self referenceProperties];
	return @"";
}
@end

@implementation ZKDescribeSObject (Reporting)
- (NSSet *)namesOfAllReferencedObjects {
	NSMutableSet *names = [NSMutableSet setWithCapacity:20];
	ZKChildRelationship *cr;
	NSEnumerator *e = [[self childRelationships] objectEnumerator];
	while (cr = [e nextObject]) 
		[names addObject:[cr childSObject]];
	ZKDescribeField *f;
	e = [[self fields] objectEnumerator];
	while (f = [e nextObject]) {
		if (![[f type] isEqualToString:@"reference"]) continue;
		[names addObjectsFromArray:[f referenceTo]];
	}
	return names;
}
@end

@implementation ReportDocument

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

- (BOOL)haveAllDescribes:(DescribeListDataSource *)dataSource {
	if (![dataSource hasDescribe:sobjectType]) return NO;
	ZKDescribeSObject *desc = [dataSource describe:sobjectType];
	NSString *t;
	NSEnumerator *e = [[desc namesOfAllReferencedObjects] objectEnumerator];
	while (t = [e nextObject]) {
		if (![dataSource hasDescribe:t]) return NO;
	}
	return YES;
}

- (void)describeWithProgress:(DescribeListDataSource *)dataSource {
	[self setDescribesDone:0];
	if (![dataSource hasDescribe:sobjectType]) 
		[self setTotalObjects:[[dataSource SObjects] count]];
	[tabview selectTabViewItemWithIdentifier:@"progress"];
	ZKDescribeSObject *desc = [dataSource describe:sobjectType];
	NSSet *allTypes = [desc namesOfAllReferencedObjects];
	[self setTotalObjects:[allTypes count]+1];
	[self setDescribesDone:1];
	NSString *t;
	NSEnumerator *e = [allTypes objectEnumerator];
	while (t = [e nextObject]) {
		[dataSource describe:t];
		[self setDescribesDone:describesDone+1];
	}
}

-(void)renderFieldTable:(NSMutableString *)s sobject:(ZKDescribeSObject *)desc {
	NSString *blueKey = [[NSBundle mainBundle] pathForResource:@"key_b" ofType:@"png"];
	NSString *redKey  = [[NSBundle mainBundle] pathForResource:@"key_r" ofType:@"png"];

	[s appendString:@"<table cellspacing='0' cellpadding='0'><tr><th colspan='2'>Field</th><th>Label</th><th>Type</th><th>Properties</th><tr>"];
	for (ZKDescribeField *f in [desc fields]) {
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
	[sobjectType release];
	sobjectType = [type copy];
	if (![self haveAllDescribes:newDataSource]) {
		[self describeWithProgress:newDataSource];
	}
	[schemaView setDescribesDataSource:newDataSource];
	[[schemaView centralBox] setViewMode:vmAllFields];
	[schemaView setCentralSObject:[newDataSource describe:sobjectType]];
	NSRect bounds = [schemaView bounds];
	
	NSRect offscreenRect = NSMakeRect(0.0, 0.0, bounds.size.width - 40.0, bounds.size.height);
	NSBitmapImageRep* offscreenRep = nil;
	offscreenRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nil
	                        pixelsWide:offscreenRect.size.width 
	                        pixelsHigh:offscreenRect.size.height 
	                        bitsPerSample:8 
	                        samplesPerPixel:4 
	                        hasAlpha:YES 
	                        isPlanar:NO 
	                        colorSpaceName:NSCalibratedRGBColorSpace 
	                        bitmapFormat:0 
	                        bytesPerRow:(4 * offscreenRect.size.width) 
	                        bitsPerPixel:32];

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
	[s appendFormat:@"<img src='schema://%@'/>", type];

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
	[sp setRequiredFileType:@"pdf"];
	[sp setTitle:@"Save Schema Report"];
	NSWindow *window = [[[self windowControllers] objectAtIndex:0] window];
	NSArray *dirs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *dir = [dirs count] > 0 ? [dirs objectAtIndex:0] : NSHomeDirectory(); 
	[sp beginSheetForDirectory:dir file:sobjectType modalForWindow:window modalDelegate:self didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void  *)contextInfo {
	if (NSOKButton == returnCode) {
		NSView *docView = [[[webview mainFrame] frameView] documentView];
		NSData *pdf =  [docView dataWithPDFInsideRect:[docView bounds]];
	    [pdf writeToFile:[sheet filename] atomically:YES];
	}
}

- (BOOL)enabledButtons {
	return enabledButtons;
}

- (void)setEnabledButtons:(BOOL)newEnabledButtons {
	enabledButtons = newEnabledButtons;
}

@end
