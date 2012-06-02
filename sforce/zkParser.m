// Copyright (c) 2008-2010 Simon Fell
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

#import "zkParser.h"

@implementation zkElement

-(id)initWithDocument:(xmlDocPtr)d node:(xmlNodePtr)n parent:(zkElement *)p {
	self = [super init];
	parent = [p retain];
	doc = d;
	node = n;
	return self;
}

-(id)initWithDocument:(xmlDocPtr)d {
	return [self initWithDocument:d node:xmlDocGetRootElement(d) parent:nil];
}

-(id)initWithNode:(xmlNodePtr)n parent:(zkElement *)p {
	return [self initWithDocument:nil node:n parent:p];
}

-(id)copyWithZone:(NSZone *)z {
	return [[zkElement allocWithZone:z] initWithDocument:doc node:node parent:parent == nil ? self : parent];
}

-(void)dealloc {
	[parent release];
	xmlFreeDoc(doc);
	[super dealloc];
}

- (NSString *)name {
	return [NSString stringWithUTF8String:(const char *)node->name];
}

- (NSString *)namespace {
	return [NSString stringWithUTF8String:(const char *)node->ns->href];
}

- (NSString *)stringValue {
	xmlChar *v = xmlNodeListGetString(doc, node->xmlChildrenNode, 1);
	NSString *s = v == NULL ? nil : [NSString stringWithUTF8String:(const char *)v];
	xmlFree(v);
	return s;
}

- (NSString *)attributeValue:(NSString *)name ns:(NSString *)namespace {
	const xmlChar * n = (const xmlChar *)[name UTF8String];
	const xmlChar * ns = (const xmlChar *)[namespace UTF8String];
	xmlChar *v = xmlGetNsProp(node, n, ns);
	if (v == NULL) return nil;
	NSString *sv = [NSString stringWithUTF8String:(const char *)v];
	xmlFree(v);
	return sv;
}

- (id)childElements:(NSString *)name ns:(NSString *)namespace checkNs:(BOOL)checkNs all:(BOOL)returnAll {
	NSMutableArray *results = returnAll ? [NSMutableArray array] : nil;
	const xmlChar * n = (const xmlChar *)[name UTF8String];
	const xmlChar * ns = (const xmlChar *)[namespace UTF8String];
	xmlNodePtr cur = node->xmlChildrenNode;
	while (cur != NULL) {
		if ((n == NULL) || (!xmlStrcmp(cur->name, n))) {
			if((!checkNs) || (!xmlStrcmp(cur->ns->href, ns))) {
				zkElement *e = [[[zkElement alloc] initWithNode:cur parent:self] autorelease]; 
				if (!returnAll) return e;
				[results addObject:e];
			}
 	    }
		cur = cur->next;
	}
	return results;
}

- (zkElement *)childElement:(NSString *)name ns:(NSString *)namespace {
	return [self childElements:name ns:namespace checkNs:YES all:NO];
}

- (zkElement *)childElement:(NSString *)name {
	return [self childElements:name ns:nil checkNs:NO all:NO];
}

- (NSArray *)childElements:(NSString *)name ns:(NSString *)namespace {
	return [self childElements:name ns:namespace checkNs:YES all:YES];
}

- (NSArray *)childElements:(NSString *)name {
	return [self childElements:name ns:nil checkNs:NO all:YES];
}

- (NSArray *)childElements {
	return [self childElements:nil ns:nil checkNs:NO all:YES];
}

@end

@implementation zkParser

+(zkElement *)parseData:(NSData *)data {
	xmlDocPtr doc = xmlReadMemory([data bytes], [data length], "noname.xml", NULL, 0);
	if (doc != nil)
		return [[[zkElement alloc] initWithDocument:doc] autorelease];
	return nil;
}

@end
