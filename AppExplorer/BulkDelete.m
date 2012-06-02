// Copyright (c) 2009 Simon Fell
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

#import "BulkDelete.h"
#import "ProgressController.h"
#import "EditableQueryResultWrapper.h"
#import "zkQueryResult.h"
#import "zkSObject.h"
#import "zkSforceClient.h"
#import "QueryResultTable.h"
#import "zkSaveResult.h"

@interface BulkDelete ()
-(void)doDeleteFrom:(int)start length:(int)length;

@property (retain) QueryResultTable *table;
@end

@interface DeleteOperation : NSOperation {
	BulkDelete *bulkDelete;
	int			start, len;
}
-(id)initWithDelete:(BulkDelete *)bd startAt:(int)start length:(int)l;
@end

@implementation DeleteOperation 

-(id)initWithDelete:(BulkDelete *)bd startAt:(int)s length:(int)l {
	self = [super init];
	bulkDelete = [bd retain];
	start = s;
	len = l;
	return self;
}

-(void)dealloc {
	[bulkDelete release];
	[super dealloc];
}

-(void)main {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	[bulkDelete doDeleteFrom:start length:len];
	[pool release];
}

@end

@implementation BulkDelete

@synthesize table;

-(void)dealloc {
	[progress release];
	[queue release];
	[indexes release];
	[sfdcIds release];
	[client release];
	[results release];
	[table release];
	[super dealloc];
}

-(id)initWithClient:(ZKSforceClient *)c {
	self = [super init];
	progress = [[ProgressController alloc] init];
	queue = [[NSOperationQueue alloc] init];
	[queue setMaxConcurrentOperationCount:1];
	client = [[c copy] retain];
	return self;
}

-(void)extractRows:(EditableQueryResultWrapper *)dataSource {
	NSSet *idxSet = [dataSource indexesOfCheckedRows];
	ZKQueryResult *data = [dataSource queryResult];
	NSMutableArray *ia  = [NSMutableArray arrayWithCapacity:[idxSet count]];
	NSMutableArray *ids = [NSMutableArray arrayWithCapacity:[idxSet count]];
	for (NSNumber *idx in idxSet) {
		[ia addObject:idx];
		ZKSObject *row = [[data records] objectAtIndex:[idx intValue]];
		[ids addObject:[row id]];
	}
	indexes = [ia retain];
	sfdcIds = [ids retain];
	results = [[NSMutableArray arrayWithCapacity:[idxSet count]] retain];
}

-(void)performBulkDelete:(QueryResultTable *)queryResultTable window:(NSWindow *)modalWindow {
	[self setTable:queryResultTable];
	EditableQueryResultWrapper *dataSource = [queryResultTable wrapper];
	[progress setProgressLabel:[NSString stringWithFormat:@"Deleting %d rows", [dataSource numCheckedRows]]];
	[progress setProgressValue:1.0];
	[NSApp beginSheet:[progress progressWindow] modalForWindow:modalWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
	[self extractRows:dataSource];

	// enqueue delete operations
	int start = 0;
	int chunk = 50;
	do {
		int len =[indexes count] - start;
		if (len > chunk) len = chunk;
		DeleteOperation *op = [[[DeleteOperation alloc] initWithDelete:self startAt:start length:len] autorelease];
		[queue addOperation:op];
		start += len;
	} while (start < [indexes count]);
}

-(void)deletesFinished {
	int cnt = 0;
	// save errors to table
	[[table wrapper] clearErrors];
	NSMutableArray *deleted = [NSMutableArray array];
	for (ZKSaveResult *r in results) {
		NSNumber *idx = [indexes objectAtIndex:cnt];
		if ([r success]) {
			[deleted addObject:idx];
			[[table wrapper] setChecked:NO onRowWithIndex:idx];
		} else {
			[[table wrapper] addError:[r description] forRowIndex:idx];
		}
		++cnt;
	}
	[table showHideErrorColumn];
	// remove the successfully deleted rows from the queryResults.
	NSArray *sorted = [deleted sortedArrayUsingSelector:@selector(compare:)];
	id ctx = [[table wrapper] createMutatingRowsContext];
	NSNumber *idx;
	NSEnumerator *e = [sorted reverseObjectEnumerator];
	while (idx = [e nextObject])
		[[table wrapper] remmoveRowAtIndex:[idx intValue] context:ctx];
	[[table wrapper] updateRowsFromContext:ctx];
	[table replaceQueryResult:[[table wrapper] queryResult]];
	
	// remove the progress sheet, and tidy up
	[NSApp endSheet:[progress progressWindow]];
	[[progress progressWindow] orderOut:self];
	[self release]; // we're outa here
}

-(void)aboutToDeleteFromIndex:(NSNumber *)idx {
	NSString *l = [NSString stringWithFormat:@"Deleting %d of %d rows", [idx intValue], [indexes count]];
	[progress setProgressLabel:l];
}

-(void)doDeleteFrom:(int)start length:(int)length {
	[self performSelectorOnMainThread:@selector(aboutToDeleteFromIndex:) withObject:[NSNumber numberWithInt:start+length] waitUntilDone:NO];
	NSArray *ids = [sfdcIds subarrayWithRange:NSMakeRange(start, length)];
	NSArray *res = [client delete:ids];
	[results addObjectsFromArray:res];
	if ([results count] == [sfdcIds count]) {
		// all done, lets wrap up
		[self performSelectorOnMainThread:@selector(deletesFinished) withObject:nil waitUntilDone:NO];
	}
}

@end
