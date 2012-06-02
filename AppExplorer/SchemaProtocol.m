//
//  SchemaProtocol.m
//  webkitTest
//
//  Created by Simon Fell on 1/13/07.
//  Copyright 2007 Simon Fell. All rights reserved.
//

#import "SchemaProtocol.h"

NSString *SchemaProtocolSchema = @"schema";
NSData *theData;

@implementation SchemaProtocol

+ (void)setData:(NSData *)data {
	theData = [data retain];
}

+ (void)initialize {
	[NSURLProtocol registerClass:[SchemaProtocol class]];
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)theRequest
{
    return ([[[theRequest URL] scheme] caseInsensitiveCompare: SchemaProtocolSchema] == NSOrderedSame);
}

+(NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
}

- (void)startLoading
{
    id<NSURLProtocolClient> client = [self client];
    NSURLRequest *request = [self request];
	
	NSURLResponse *response = [[NSURLResponse alloc] initWithURL:[request URL] MIMEType:@"image/tiff" expectedContentLength:-1 textEncodingName:nil];
	[client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
	[client URLProtocol:self didLoadData:theData];
	[client URLProtocolDidFinishLoading:self];
	[response release];
	[theData release];
	theData = nil;
}

- (void)stopLoading
{
}

@end
