// Copyright (c) 2006 Simon Fell
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


#import "zkEnvelope.h"

@implementation ZKEnvelope

enum envState {
	inEnvelope = 1,
	inHeaders = 2,
	inBody = 3
};

- (void)start:(NSString *)primaryNamespceUri {
	[env release];
	env = [NSMutableString stringWithFormat:@"<s:Envelope xmlns:s='http://schemas.xmlsoap.org/soap/envelope/' xmlns='%@'>", primaryNamespceUri];
	state = inEnvelope;
}

- (void)moveToHeaders {
	if (state == inBody)
		@throw [NSException exceptionWithName:@"Illegal State Exception" reason:@"Unable to write headers once we've moved to the body" userInfo:nil];
	if (state == inHeaders) return;
	[self startElement:@"s:Header"];
	state = inHeaders;
}

- (void)writeSessionHeader:(NSString *)sessionId {
	if ([sessionId length] == 0) return;
	[self moveToHeaders];
	[self startElement:@"SessionHeader"];
	[self addElement:@"sessionId" elemValue:sessionId];
	[self endElement:@"SessionHeader"];
}

- (void)writeCallOptionsHeader:(NSString *)clientId {
	if ([clientId length] == 0) return;
	[self moveToHeaders];
	[self startElement:@"CallOptions"];
	[self addElement:@"client" elemValue:clientId];
	[self endElement:@"CallOptions"];
}

- (void)writeMruHeader:(BOOL)updateMru {
	if (!updateMru) return;
	[self moveToHeaders];
	[self startElement:@"MruHeader"];
	[self addElement:@"updateMru" elemValue:@"true"];
	[self endElement:@"MruHeader"];
}

- (void) moveToBody {
	if (state == inHeaders)
		[self endElement:@"s:Header"];
	if (state != inBody) 
		[self startElement:@"s:Body"];
	state = inBody;
}

- (void) addElement:(NSString *)elemName elemValue:(id)elemValue {
	if ([elemValue isKindOfClass:[NSString class]])      	[self addElementString:elemName elemValue:elemValue];
	else if ([elemValue isKindOfClass:[NSArray class]]) 	[self addElementArray:elemName elemValue:elemValue];
	else if ([elemValue isKindOfClass:[ZKSObject class]]) 	[self addElementSObject:elemName elemValue:elemValue];
	else [self addElementString:elemName elemValue:[elemValue stringValue]];
}

- (void) addElementArray:(NSString *)elemName elemValue:(NSArray *)elemValues {
	NSEnumerator *e = [elemValues objectEnumerator];
	id o;
	while(o = [e nextObject])
		[self addElement:elemName elemValue:o];
}

- (void) addElementString:(NSString *)elemName elemValue:(NSString *)elemValue {
	[self startElement:elemName];
	[self writeText:elemValue];
	[self endElement:elemName];
}

- (void) addElementSObject:(NSString *)elemName elemValue:(ZKSObject *)sobject {
	[self startElement:elemName];
	[self addElement:@"type" elemValue:[sobject type]];
	[self addElement:@"fieldsToNull" elemValue:[sobject fieldsToNull]];
	if ([sobject id]) 
		[self addElement:@"Id" elemValue:[sobject id]];
	NSEnumerator *e = [[sobject fields] keyEnumerator];
	NSString *key;
	while(key = [e nextObject]) {
		[self addElement:key elemValue:[[sobject fields] valueForKey:key]];
	}
	[self endElement:elemName];
}

- (void) writeText:(NSString *)text  {
	unichar c;
	unsigned int i, len = [text length];
	for(i = 0; i < len; i++)
	{
		c = [text characterAtIndex:i];
		switch (c)
		{
			case '<' : [env appendString:@"&lt;"]; break;
			case '>' : [env appendString:@"&gt;"]; break;
			case '&' : [env appendString:@"&amp;"]; break;
			default  : [env appendFormat:@"%C", c];
		}
	}
}

- (void )startElement:(NSString *)elemName {
	[env appendFormat:@"<%@>", elemName];
}

- (void )endElement:(NSString *)elemName {
	[env appendFormat:@"</%@>", elemName];
}

- (NSString *)end {
	[env appendString:@"</s:Envelope>"];
	return env;
}

@end
