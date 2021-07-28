// Copyright (c) 2021 Simon Fell
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

#import "Completion.h"
#import "ColorizerStyle.h"

@interface Icons()
@property (strong,nonatomic) NSDictionary<NSNumber*, NSImage*> *icons;
@end

@implementation Icons

static Icons *iconInstance;

+(void)initialize {
    iconInstance = [Icons new];
    ColorizerStyle *style = [ColorizerStyle styles];
    NSSize sz = NSMakeSize(64,64);
    NSImage *lit = [NSImage imageWithSize:sz flipped:NO drawingHandler:[self iconDrawingHandler:@"V" color:style.literalColor]];
    iconInstance.icons = @{
        @(TTField) : [NSImage imageWithSize:sz flipped:NO drawingHandler:[self iconDrawingHandler:@"F" color:style.fieldColor]],
        @(TTSObject) : [NSImage imageWithSize:sz flipped:NO drawingHandler:[self iconDrawingHandler:@"O" color:style.sobjectColor]],
        @(TTRelationship) : [NSImage imageWithSize:NSMakeSize(64, 64) flipped:NO drawingHandler:[self iconDrawingHandler:@"R" color:style.relColor]],
        @(TTOperator) : [NSImage imageWithSize:sz flipped:NO drawingHandler:[self iconDrawingHandler:@"Op" color:style.keywordColor]],
        @(TTKeyword) : [NSImage imageWithSize:sz flipped:NO drawingHandler:[self iconDrawingHandler:@"K" color:style.keywordColor]],
        @(TTTypeOf) : [NSImage imageWithSize:sz flipped:NO drawingHandler:[self iconDrawingHandler:@"T" color:style.keywordColor]],
        @(TTFunc) : [NSImage imageWithSize:sz flipped:NO drawingHandler:[self iconDrawingHandler:@"\xF0\x9D\x91\x93"  color:style.funcColor]],
        @(TTLiteral) : lit,
        @(TTLiteralList) : lit,
        @(TTLiteralString) : lit,
        @(TTLiteralNumber) : lit,
        @(TTLiteralDate) : lit,
        @(TTLiteralDateTime) : lit,
        @(TTLiteralNamedDateTime) : [NSImage imageWithSize:sz flipped:NO drawingHandler:[self iconDrawingHandler:@"D" color:style.literalColor]],
        @(TTLiteralBoolean) : lit,
        @(TTLiteralNull) : lit,
    };
}

+(BOOL(^)(NSRect))iconDrawingHandler:(NSString*)txt color:(NSColor *)color {
    NSDictionary *txtStyle = @{
        NSForegroundColorAttributeName: [NSColor whiteColor],
        NSFontAttributeName: [NSFont boldSystemFontOfSize:48],
    };
    return ^BOOL(NSRect dstRect) {
        CGContextRef const context = NSGraphicsContext.currentContext.CGContext;
        CGPathRef box = CGPathCreateWithRoundedRect(CGRectInset(dstRect, 4, 4), 8, 8, nil);
        [color setStroke];
        [[color blendedColorWithFraction:0.75 ofColor:[NSColor blackColor]] setFill];
        CGContextAddPath(context, box);
        CGContextSetLineWidth(context, 6);
        CGContextDrawPath(context, kCGPathFillStroke);
        NSSize sz = [txt sizeWithAttributes:txtStyle];
        NSRect txtRect = NSMakeRect((dstRect.size.width-ceil(sz.width))/2, ((dstRect.size.height-ceil(sz.height))/2)+1, ceil(sz.width), ceil(sz.height));
        [txt drawInRect:txtRect withAttributes:txtStyle];
        CGPathRelease(box);
        return YES;
    };
}

+(NSImage*)iconFor:(TokenType)t {
    return iconInstance.icons[@(t)];
}

@end


@implementation Completion
+(NSArray<Completion*>*)completions:(NSArray<NSString*>*)txt type:(TokenType)ty {
    NSMutableArray *r = [NSMutableArray arrayWithCapacity:txt.count];
    for (NSString *t in txt) {
        [r addObject:[Completion txt:t type:ty]];
    }
    return r;
}

+(instancetype)txt:(NSString*)txt type:(TokenType)t {
    return [self display:txt insert:txt finalInsertion:txt type:t];
}

+(instancetype)display:(NSString*)d insert:(NSString*)i finalInsertion:(NSString*)fi type:(TokenType)t {
    Completion *c = [self new];
    c.displayText = d;
    c.nonFinalInsertionText = i;
    c.finalInsertionText = fi;
    c.type = t;
    c.icon = [Icons iconFor:t];
    return c;
}

-(NSString*)description {
    return self.displayText;
}

-(NSComparisonResult)caseInsensitiveCompare:(Completion*)rhs {
    return [self.displayText caseInsensitiveCompare:rhs.displayText];
}

@end
