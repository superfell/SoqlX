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

#import "SchemaView.h"
#import "SObjectBox.h"
#import "DataSources.h"
#import "Explorer.h"
#import "WeightedSObject.h"
#import "../sforce/zkChildRelationship.h"
#import "../sforce/zkDescribeSObject.h"
#import "RRGlossCausticShader.h"

@interface SchemaView (Private)
- (void)removeRelatedViews;
- (NSArray *)childSObjectsSkipping:(NSArray *)toSkip;
- (NSArray *)foreignKeySObjects;
- (NSArray *)createSObjectBoxes:(NSArray *)sobjects withColor:(NSColor *)aColor;
@end


@interface NSBezierPath (Intersections)
- (float)xIntersectionForY:(float)y;
@end

@implementation NSBezierPath (Intersections)
- (float)xIntersectionForY:(float)y {
	NSPoint point[3];
	NSPoint startPos;
	[self elementAtIndex:0 associatedPoints:point];
	startPos = point[0];
	int idx;
	for (idx = 1; idx < [self elementCount]; idx++) {
		[self elementAtIndex:idx associatedPoints:point];
		if ((y >= startPos.y) && (y <= point[0].y)) {
			return startPos.x + (((y - startPos.y) / (point[0].y - startPos.y)) * (point[0].x - startPos.x));
		}
		startPos = point[0];
	}
	return startPos.x;
}
@end


@implementation SchemaView

- (void)dealloc {
	[centralBox release];
	[describes release];
	[relatedBoxes release];
	[foreignKeys release];
	[children release];
	[primaryColor release];
	[foreignKeyColor release];
	[childRelColor release];
	[super dealloc];
}

- (DescribeListDataSource *)describesDataSource {
	return describes;
}

- (void)setDescribesDataSource:(DescribeListDataSource *)newDataSource {
	if (newDataSource != describes) {
		[describes release];
		describes = [newDataSource retain];
	}
}

// Printing
- (void)print:(id)sender {
	isPrinting = YES;
    NSPrintOperation *pop = [NSPrintOperation printOperationWithView:self];
	[[pop printInfo] setVerticalPagination:NSFitPagination];
	[[pop printInfo] setHorizontalPagination:NSFitPagination];
	[pop runOperation];
	isPrinting = NO;
}

// NSView
- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
		primaryColor = [[NSColor purpleColor] retain];
		foreignKeyColor = [[NSColor colorWithCalibratedRed:0.3 green:0.3 blue:0.8 alpha:1.0] retain];
		childRelColor = [[NSColor orangeColor] retain];
		isPrinting = NO;
		
		NSSize sz = NSMakeSize(200, 100);
		NSPoint pt = NSMakePoint(NSMidX(frame) - sz.width/2, NSMidY(frame) - sz.height/2);
		NSRect rect = NSMakeRect(pt.x, pt.y, sz.width,sz.height);
		centralBox = [[SObjectBox alloc] initWithFrame:rect andView:self];
		[centralBox setColor:primaryColor];
		[[self superview] setPostsBoundsChangedNotifications: YES];
		[[NSNotificationCenter defaultCenter] addObserver:self
		        	selector: @selector(boundsDidChangeNotification:)
		        	name: NSViewBoundsDidChangeNotification
		        	object: [self superview]];
    }
    return self;
}

- (void) boundsDidChangeNotification:(NSNotification *)notification {
	needsFullRedraw = YES;
	[centralBox resetTrackingRect];
	[foreignKeys makeObjectsPerformSelector:@selector(resetTrackingRect)];
	[children makeObjectsPerformSelector:@selector(resetTrackingRect)];
} 

- (void)drawRelationshipLine:(SObjectBox *)relBox fieldNameOnPrimarySObject:(NSString *)primaryField fieldNameOnRelatedSObject:(NSString *)secondaryField withColor:(NSColor *)aColor {
	NSBezierPath *path = [NSBezierPath bezierPath];
	NSRect primary   = [centralBox rectOfFieldPaddedToEdges:primaryField];
	if (NSIsEmptyRect(primary)) primary = [centralBox rectOfFieldPaddedToEdges:@"Id"];
	NSRect secondary = [relBox rectOfFieldPaddedToEdges:secondaryField];
	if (NSIsEmptyRect(secondary)) secondary = [relBox rectOfFieldPaddedToEdges:@"Id"];
	int offset1, offset2;
	NSPoint startPoint, endPoint;
	if (relBox == centralBox) {
		startPoint = NSMakePoint(NSMinX(primary), NSMidY(primary));
		endPoint = NSMakePoint(NSMinX(secondary), NSMidY(secondary));
		offset1 = -75;
		offset2 = -75;
		// self references always use the color of the self referencing entity
		aColor = [relBox color];
	} else if (NSMaxX(primary) < NSMinX(secondary)) {
		startPoint = NSMakePoint(NSMaxX(primary), NSMidY(primary));
		endPoint = NSMakePoint(NSMinX(secondary), NSMidY(secondary));
		offset1 = 50;
		offset2 = -50;
	} else {
		startPoint = NSMakePoint(NSMinX(primary), NSMidY(primary));
		endPoint = NSMakePoint(NSMaxX(secondary), NSMidY(secondary));
		offset1 = -50;
		offset2 = 50;
	}
	//[path setLineWidth:1.0];
	if ([relBox isHighlighted]) {
		//[path setLineWidth:3.0];
		[[aColor shadowWithLevel:0.3] set];
	} else {
		[aColor set];
	}
	[path moveToPoint:startPoint];
	[path curveToPoint:endPoint controlPoint1:NSMakePoint(startPoint.x+offset1, startPoint.y) controlPoint2:NSMakePoint(endPoint.x+offset2, endPoint.y)];
	[path stroke];
}

- (BOOL)needsFullRedraw {
	return needsFullRedraw;
}

- (void)setNeedsFullRedraw:(BOOL)aValue {
	if (needsFullRedraw == aValue) return;
	needsFullRedraw = aValue;
	if (needsFullRedraw)
		[self setNeedsDisplay:YES];
}

// NSTransitionView
- (void)drawBackground:(NSRect)rect {
	if (!isPrinting && !needsFullRedraw) return;
	[[NSColor whiteColor] set];
	NSRectFill(rect);
}

-(void)drawSelectAnSObject {
	NSRect b = [self bounds];
	float bx = 250, by = 40;
	NSRect box = NSMakeRect(b.origin.x + (b.size.width-bx)/2, b.origin.y+(b.size.height-by)/2 , bx, by);
	NSString *txt= @"Please select an SObject";
	NSBezierPath *p = [NSBezierPath bezierPathWithRoundedRect:box xRadius:10 yRadius:10];

    NSGraphicsContext *nsContext = [NSGraphicsContext currentContext];
    [nsContext saveGraphicsState];
    [p addClip];
	
	RRGlossCausticShader *shader = [[[RRGlossCausticShader alloc] init] autorelease];
	[shader setNoncausticColor:[NSColor colorWithCalibratedRed:0.1 green:0.1 blue:1 alpha:1]];
	[shader update];
	[shader drawShadingFromPoint:NSMakePoint(NSMinX(box), NSMaxY(box)) toPoint:NSMakePoint(NSMinX(box), NSMinY(box)) inContext:[nsContext graphicsPort]];

    [nsContext restoreGraphicsState];

    NSMutableParagraphStyle *st = [[[NSMutableParagraphStyle alloc] init] autorelease];
    [st setParagraphStyle:[NSParagraphStyle defaultParagraphStyle]];
	[st setAlignment:NSCenterTextAlignment];
	NSDictionary *a = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSColor whiteColor], NSForegroundColorAttributeName,
		[NSFont boldSystemFontOfSize:14], NSFontAttributeName,
		st, NSParagraphStyleAttributeName,
		nil];
	NSSize sz = [txt sizeWithAttributes:a];
	box.origin.y = NSMidY(box) - (sz.height/2);
	box.size.height = sz.height;
	[txt drawInRect:box withAttributes:a];
}

// NSTransitionView
- (void)drawForeground:(NSRect)rect {
	if ([centralBox sobject] == nil) {
		[self drawSelectAnSObject];
		return;
	}
	if (isPrinting || needsFullRedraw) {
		for (ZKDescribeField *field in [centralBox fieldsToDisplay]) {
			NSArray *refs = [field referenceTo];
			for (NSString *refSObjectName in refs) {
				SObjectBox *refBox = [relatedBoxes objectForKey:refSObjectName];
				if ((refBox == nil) && [refSObjectName isEqualTo:[[centralBox sobject] name]])
					refBox = centralBox;
				[self drawRelationshipLine:refBox fieldNameOnPrimarySObject:[field name] fieldNameOnRelatedSObject:@"Id" withColor:foreignKeyColor];
			}
		}
		for (ZKChildRelationship *cr in [[centralBox sobject] childRelationships]) { 
			SObjectBox *refBox = [relatedBoxes objectForKey:[cr childSObject]];
			if (refBox == nil) continue;
			[self drawRelationshipLine:refBox fieldNameOnPrimarySObject:@"Id" fieldNameOnRelatedSObject:[cr field] withColor:childRelColor];
		}
	}
	[centralBox drawRect:rect forceRedraw:isPrinting || needsFullRedraw];
	for (SObjectBox *box in [foreignKeys objectEnumerator])  
		[box drawRect:rect  forceRedraw:isPrinting || needsFullRedraw];
	for (SObjectBox *box in children)  
		[box drawRect:rect  forceRedraw:isPrinting || needsFullRedraw];
		
	[self setNeedsFullRedraw:NO];
}

// NSView
- (void)resizeWithOldSuperviewSize:(NSSize)oldBoundsSize {
	[super resizeWithOldSuperviewSize:oldBoundsSize];
	[self layoutBoxes];
}

typedef enum ArcPositionStyle {
	leftHandSide,
	rightHandSide
} ArcPositionStyle;

static const float minSpacerSize = 5.0f;

- (void)getHeightOfboxes:(NSArray *)boxes totalHeight:(float *)totalHeight heightWithSpacers:(float *)withSpacers {
	float height = 0;
	SObjectBox *box;
	NSEnumerator *e = [boxes objectEnumerator];
	while (box = [e nextObject]) {
		height += [box size].height;
	}
	*totalHeight = height;
	*withSpacers = height + (minSpacerSize * ([boxes count]+2)) + 75; 
}

- (float)layoutBoxesOnArc:(NSArray *)boxes position:(ArcPositionStyle)positionStyle {
	float totalSize, totalSizeWithSpacers;
	[self getHeightOfboxes:boxes totalHeight:&totalSize heightWithSpacers:&totalSizeWithSpacers];
	NSSize visibleSize = [[self superview] frame].size;
	if (totalSizeWithSpacers >= visibleSize.height) {
		visibleSize.height = totalSizeWithSpacers;
	} 
	NSRect bounds = [self bounds];
	bounds.size.height = visibleSize.height;
	float arcStartX = NSMidX(bounds) /2 * (positionStyle == leftHandSide ? 1 : 3);
	float arcOuterX = NSMidX(bounds) /6 * (positionStyle == leftHandSide ? 1 : 11);
	float spacerSize = MAX(minSpacerSize, (bounds.size.height - totalSize) / (1+[boxes count]));
	NSPoint startingPos = NSMakePoint(arcStartX, spacerSize);
	NSBezierPath *path = [NSBezierPath bezierPath];
	[path moveToPoint:startingPos];
	NSPoint controlPoint = NSMakePoint(arcOuterX, NSMidY(bounds));
	[path curveToPoint:NSMakePoint(arcStartX, bounds.size.height - spacerSize) controlPoint1:controlPoint controlPoint2:controlPoint];
	NSBezierPath *flatPath = [path bezierPathByFlatteningPath];
	NSEnumerator *e = [boxes objectEnumerator];
	SObjectBox *box;
	while (box = [e nextObject]) {
		NSSize boxSize = [box size];
		[box setOrigin:NSMakePoint(startingPos.x - (boxSize.width/2), startingPos.y)];
		startingPos.y += boxSize.height + spacerSize; 
		startingPos.x = [flatPath xIntersectionForY:startingPos.y+(boxSize.height/2)];
	}
	return visibleSize.height;
}

- (void)layoutBoxes {
	NSSize cb = [centralBox size];
	NSSize visibleSize = [[self superview] frame].size;
	if (cb.height + (minSpacerSize*2) > visibleSize.height) {
		visibleSize.height = cb.height + (minSpacerSize*2);
	} 
	visibleSize.height = MAX(visibleSize.height, [self layoutBoxesOnArc:foreignKeys position:leftHandSide]);
	visibleSize.height = MAX(visibleSize.height, [self layoutBoxesOnArc:children position:rightHandSide]);
	[self setFrameSize:visibleSize];
	NSRect bounds = [self bounds];
	[centralBox setOrigin:NSMakePoint(NSMidX(bounds) - (cb.width/2), NSMidY(bounds) - (cb.height/2))];
	[self setNeedsFullRedraw:YES];
}

// SchemaView
- (ZKDescribeSObject *)centralSObject {
	return [centralBox sobject];
}

- (void)addReferencedSObjectsFromFieldEnumerator:(NSEnumerator *)enm results:(NSMutableDictionary *)results trackWeights:(BOOL)trackWeights {
	ZKDescribeField *field;
	NSString *refSObject;
	uint weightIndex = 0;
	while (field = [enm nextObject]) {
		if ([[field referenceTo] count] == 0) continue;
		NSEnumerator *refe = [[field referenceTo] objectEnumerator];
		while (refSObject = [refe nextObject]) {
			if ([refSObject isEqualTo:[[centralBox sobject] name]]) continue;
			WeightedSObject *weight = [results objectForKey:refSObject];
			if (weight == nil) {
				weight = [WeightedSObject weightedSObjectForSObject:refSObject];
				[results setObject:weight forKey:refSObject];
			}
			if (trackWeights)
				[weight addWeight:weightIndex];
		}
		++weightIndex;
	}
}

- (NSArray *)foreignKeySObjects {
	NSMutableDictionary *orderedWeights = [NSMutableDictionary dictionary];
	[self addReferencedSObjectsFromFieldEnumerator:[[centralBox fieldsToDisplay] objectEnumerator] results:orderedWeights trackWeights:YES];
	[self addReferencedSObjectsFromFieldEnumerator:[[[centralBox sobject] fields] objectEnumerator] results:orderedWeights trackWeights:NO];
	return [orderedWeights keysSortedByValueUsingSelector:@selector(compare:)];
}

// all SObjects that have a FK to the central sobject, except those in the toSkip array
- (NSArray *)childSObjectsSkipping:(NSArray *)toSkip {
	NSMutableArray *orderedRefs = [NSMutableArray array];
	NSMutableSet * refs = [NSMutableSet setWithArray:toSkip];
	NSEnumerator *e = [[[centralBox sobject] childRelationships] objectEnumerator];
	ZKChildRelationship *cr;
	while(cr = [e nextObject]) {
		if ([refs containsObject:[cr childSObject]]) continue;
		if ([[cr childSObject] isEqualTo:[[centralBox sobject] name]]) continue;
		[refs addObject:[cr childSObject]];
		[orderedRefs addObject:[cr childSObject]];
	}
	return orderedRefs;
}

- (NSArray *)createSObjectBoxes:(NSArray *)sobjects withColor:(NSColor *)aColor {
	NSRect frame = [self frame];
	NSSize sz = NSMakeSize(100,100);
	NSRect relRect = NSMakeRect(frame.origin.x, frame.origin.y, sz.width, sz.height);
	NSString *objName;
	NSEnumerator *e = [sobjects objectEnumerator];
	NSMutableArray *createdBoxes = [NSMutableArray array];
	while (objName = [e nextObject]) {
		ZKDescribeSObject *desc = [describes describe:objName];
		SObjectBox *b = [[SObjectBox alloc] initWithFrame:relRect andView:self];
		[b setSobject:desc];
		[b setIncludeFksTo:[centralBox sobject]];
		[b setViewMode:vmTitleOnly];
		[b setColor:aColor];
		relRect.origin.y += sz.height;
		[relatedBoxes setObject:b forKey:objName];
		[createdBoxes addObject:b];
		[b release];
	}	
	return createdBoxes;
}

-(void)setCentralSObjectImpl:(ZKDescribeSObject *)s {
	[centralBox setSobject:s];
	[relatedBoxes release];
	relatedBoxes = [[NSMutableDictionary alloc] init];
	NSArray *fkSObjects = [self foreignKeySObjects];
	[foreignKeys release];
	foreignKeys = [[self createSObjectBoxes:fkSObjects withColor:foreignKeyColor] retain];
	[children release];
	children = [[self createSObjectBoxes:[self childSObjectsSkipping:fkSObjects] withColor:childRelColor] retain];
	[self layoutBoxes];
}

// ScheamView
// takes a starting snapshot, recalcs the display, takes a second snapshot, then does a transition between the 2
// the base class, TransitionView does all the animation/transition work given the before & after images
- (void)setCentralSObject:(ZKDescribeSObject *)s {
	NSRect f = [self visibleRect];
	NSPoint center = NSMakePoint(NSMidX(f), NSMidY(f));
	[self setCentralSObject:s withRipplePoint:center];
}

- (void)setCentralSObject:(ZKDescribeSObject *)s withRipplePoint:(NSPoint)ripple {
	[primaryController updateProgress:YES];
	[primaryController setStatusText:[NSString stringWithFormat:@"describing schema for %@", [s name]]];
	BOOL doAnimation = [centralBox sobject] != nil;
	NSBitmapImageRep *before, *after;
	if (doAnimation) {
		before = [self bitmapImageRepForCachingDisplayInRect:[self visibleRect]];
		[self cacheDisplayInRect:[self visibleRect] toBitmapImageRep:before];
	}

	[self setCentralSObjectImpl:s];

	if (doAnimation) {	
		after = [self bitmapImageRepForCachingDisplayInRect:[self visibleRect]];
		[self cacheDisplayInRect:[self visibleRect] toBitmapImageRep:after];
	}
	
	[primaryController updateProgress:NO];
	[primaryController setStatusText:[s name]];
	if (doAnimation) 
		[self performAnimationStartingWith:before endingWith:after ripplePoint:ripple withDuration:1.0];
	[self setNeedsFullRedraw:YES];	
}

-(BOOL)delegateMouseDown:(NSEnumerator *)e withEvent:(NSEvent *)event{
	SObjectBox *box;
	while (box = [e nextObject]) {
		if ([box isHighlighted]) {
			[box mouseDown:event];
			return YES;
		}
	}
	return NO;
}

-(BOOL)delegateMouseUp:(NSEnumerator *)e withEvent:(NSEvent *)event{
	SObjectBox *box;
	while (box = [e nextObject]) {
		if ([box isHighlighted]) {
			[box mouseUp:event];
			return YES;
		}
	}
	return NO;
}

- (void)mouseDown:(NSEvent *)event {
	if ([centralBox isHighlighted])
		[centralBox mouseDown:event];
	else if (![self delegateMouseDown:[children objectEnumerator] withEvent:event])
		[self delegateMouseDown:[foreignKeys objectEnumerator] withEvent:event];
}

-(void)mouseUp:(NSEvent *)event {
	if ([centralBox isHighlighted]) 
		[centralBox mouseUp:event];
	else if (![self delegateMouseUp:[children objectEnumerator] withEvent:event])
		[self delegateMouseUp:[foreignKeys objectEnumerator] withEvent:event];
}

- (BOOL)mousePointerIsInsideRect:(NSRect)rect {
	NSPoint loc = [self convertPoint:[[self window] mouseLocationOutsideOfEventStream] fromView:nil];
	return NSPointInRect(loc, rect);
}

// addTrackingRect helper that calculates whether we're inside the rect or not
- (NSTrackingRectTag)addTrackingRect:(NSRect)rect owner:(id)owner {
	return [self addTrackingRect:rect owner:owner userData:nil assumeInside:[self mousePointerIsInsideRect:rect]];
}

-(BOOL)isOpaque {
	return YES;
}

- (SObjectBox *)centralBox {
	return centralBox;
}

@end















