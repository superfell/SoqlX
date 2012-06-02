//
//  SaveOptions.h
//  AppExplorer
//
//  Created by Simon Fell on 7/4/08.
//  Copyright 2008 Simon Fell. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class QueryResultTable;
@class ZKSforceClient;
@class ZKQueryResult;

@interface BufferedWriter : NSObject {
	NSOutputStream	*stream;
	NSMutableData	*buffer;
	NSUInteger		capacity;
}
-(id)initOnStream:(NSOutputStream *)s;

-(void)write:(const uint8_t *)data maxLength:(uint)len;
-(void)flush;
-(void)close;

@end

@interface BufferedWriter (StringHelpers) 
-(void)write:(NSString *)s;
-(void)writeQuoted:(NSString *)s;
@end

@interface ResultsSaver : NSObject {
	IBOutlet NSWindow		*progressWindow;
	IBOutlet NSView			*optionsView;
	IBOutlet NSButtonCell	*buttonAll;
	IBOutlet NSButtonCell	*buttonCurrent;
	
	BOOL				saveAll;
	NSOperationQueue	*queryQueue;
	NSOperationQueue	*saveQueue;
	BufferedWriter		*stream;
	ZKSforceClient		*client;
	QueryResultTable	*results;
	NSString			*filename;
	NSDate				*started;
	
	NSUInteger			rowsWritten;
}

-(id)initWithResults:(QueryResultTable *)res client:(ZKSforceClient *)c;

-(void)save:(NSWindow *)parentWindow;

@property (assign)   BOOL saveAll;
@property (assign) NSUInteger rowsWritten;
@property (readonly) NSUInteger totalRows;
@property (retain) NSString *filename;

@end

