//
//  SaveOptions.m
//  AppExplorer
//
//  Created by Simon Fell on 7/4/08.
//  Copyright 2008 Simon Fell. All rights reserved.
//

#import "ResultsSaver.h"
#import "QueryResultTable.h"
#import "zkQueryResult.h"
#import "zkSforceClient.h"
#import "EditableQueryResultWrapper.h"

@implementation ResultsSaver

@synthesize saveAll, rowsWritten, filename;

-(id)initWithResults:(QueryResultTable *)r client:(ZKSforceClient *)c {
	self = [super init];
	results = [r retain];
	if ([[results queryResult] queryLocator] != nil) {
		[NSBundle loadNibNamed:@"querySavePanel" owner:self];
		[buttonAll setTitle:[NSString stringWithFormat:[buttonAll title], [[results queryResult] size]]];
		[buttonCurrent setTitle:[NSString stringWithFormat:[buttonCurrent title], [[[results queryResult] records] count]]];
	}
	client = [c retain];
	queryQueue = [[NSOperationQueue alloc] init];
	[queryQueue setMaxConcurrentOperationCount:1];
	saveQueue = [[NSOperationQueue alloc] init];
	[saveQueue setMaxConcurrentOperationCount:1];
	
	return self;
}

-(void)dealloc {
	[client release];
	[stream release];
	[queryQueue release];
	[saveQueue release];
	[results release];
	[started release];
	[super dealloc];
}

- (void)save:(NSWindow *)parentWindow {
	[self retain];
	NSSavePanel *sp = [NSSavePanel savePanel];
	[sp setAccessoryView:optionsView];
	[sp beginSheetForDirectory:NSHomeDirectory() file:@"" modalForWindow:parentWindow modalDelegate:self didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:parentWindow];
}

-(NSUInteger)totalRows {
	return [[results queryResult] size];
}

-(NSArray *)columns {
	return [[results table] tableColumns];
}

-(void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode  contextInfo:(void  *)contextInfo {
	[optionsView autorelease];
	if (returnCode == NSCancelButton) {
		[self autorelease];
		return;
	}
	[self setFilename:[sheet filename]];
	[self performSelectorOnMainThread:@selector(startWrite:) withObject:contextInfo waitUntilDone:NO];
}

-(void)startWrite:(id)contextInfo {
	[self setRowsWritten:0];
	if (saveAll)
		[NSApp beginSheet:progressWindow modalForWindow:(NSWindow *)contextInfo modalDelegate:self didEndSelector:nil contextInfo:nil];
	
	started = [[NSDate date] retain];
	NSOutputStream *s = [NSOutputStream outputStreamToFileAtPath:filename append:NO];
	[s open];
	stream = [[BufferedWriter alloc] initOnStream:s];
	
	ZKQueryResult *qr = [results queryResult];
	NSTableColumn *c;
	NSEnumerator *ce = [[self columns] objectEnumerator];
	BOOL first = YES;
	while(c = [ce nextObject]) {
		if ([[[results wrapper] allSystemColumnIdentifiers] containsObject:[c identifier]])
			continue;
		if (first) first = NO;
		else [stream write:@","];
		[stream writeQuoted:[c identifier]];
	}
	[stream write:@"\r"];

	ZKSforceClient *sf = [client copyWithZone:nil];
	[client autorelease];
	client = sf;

	NSInvocationOperation *sop = [[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(writeResults:) object:qr] autorelease];
	[saveQueue addOperation:sop];
}

-(void)endWrite {
	NSTimeInterval ttaken = [[NSDate date] timeIntervalSinceDate:started];
	NSLog(@"query result saving complete, %d rows in %f seconds (%d rows per hour)", rowsWritten, ttaken, (int)(rowsWritten * 3600 / ttaken) );
	[stream close];
	if (saveAll) {
		[NSApp endSheet:progressWindow];
		[progressWindow orderOut:self];
		[progressWindow autorelease];
	}
	[self autorelease];
}

-(void)queryMore:(id)locator {
	ZKQueryResult *qr = [client queryMore:locator];
	NSInvocationOperation *sop = [[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(writeResults:) object:qr] autorelease];
	[saveQueue addOperation:sop];
}

-(void)queueQueryMore:(NSString *)ql {
	if ([ql length] == 0 || !saveAll) return;
	NSInvocationOperation *q = [[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(queryMore:) object:ql] autorelease];
	[queryQueue addOperation:q];
}

-(void)incrementRowCount:(NSNumber *)n {
	NSUInteger tr = rowsWritten + [n intValue];
	[self setRowsWritten:tr];
}

-(void)updateRowCount:(int)rows {
	[self performSelectorOnMainThread:@selector(incrementRowCount:) withObject:[NSNumber numberWithInt:rows] waitUntilDone:NO];
}

-(void)writeResults:(id)data {
	ZKQueryResult *qr = (ZKQueryResult *)data;
	[self queueQueryMore:[qr queryLocator]];
	int rows = [qr numberOfRowsInTableView:nil];
	for (int i = 0; i < rows; i++) {
		BOOL first = YES;
		for (NSTableColumn *c in [self columns]) {
			if ([[[results wrapper] allSystemColumnIdentifiers] containsObject:[c identifier]])
				continue;
			if (first) first = NO;
			else [stream write:@","];
			NSString *v = [qr tableView:nil objectValueForTableColumn:c row:i];
			[stream writeQuoted:v];
		}
		[stream write:@"\r"];
	}
	[self updateRowCount:rows];
	if ([qr done] || !saveAll) {
		[self performSelectorOnMainThread:@selector(endWrite) withObject:nil waitUntilDone:NO];
	}
}

@end

@implementation BufferedWriter 

-(id)initOnStream:(NSOutputStream *)s capacity:(NSUInteger)cap {
	self = [super init];
	stream = [s retain];
	buffer = [[NSMutableData alloc] initWithCapacity:cap];
	capacity = cap;
	return self;
}

-(id)initOnStream:(NSOutputStream *)s {
	return [self initOnStream:s capacity:64*1024];
}

-(void)dealloc {
	[stream release];
	[buffer release];
	[super dealloc];
}

-(void)write:(uint8_t *)data maxLength:(uint)len {
	if (len < (capacity - [buffer length])) {
		[buffer appendBytes:data length:len];
	} else if (len < capacity) {
		[self flush];
		[buffer appendBytes:data length:len];
	} else {
		[self flush];
		[stream write:data maxLength:len];
	}
}

-(void)flush {
	if ([buffer length] > 0) {
		[stream write:[buffer mutableBytes] maxLength:[buffer length]];
		[buffer setLength:0];
	}
}

-(void)close {
	[self flush];
	[stream close];
}

// String helpers
-(void)write:(NSString *)s {
	if (s == nil) return;
	[self write:(const uint8_t *)[s UTF8String] maxLength:[s lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];
}

-(void)writeQuoted:(NSString *)s {
	[self write:(const uint8_t *)"\"" maxLength:1];
	[self write:[s stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""]];
	[self write:(const uint8_t *)"\"" maxLength:1];
}

@end
