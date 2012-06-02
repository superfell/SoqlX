// RRUtils RRGlossCausticShader.m
//
// Copyright © 2008, Roy Ratcliffe, Lancaster, United Kingdom
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
//------------------------------------------------------------------------------

#import "RRGlossCausticShader.h"

#import "RRExponentialFunction.h"
#import "RRCausticColorMatcher.h"
#import "RRLuminanceFromRGBComponents.h"

struct RRGlossCausticShaderInfo
{
	RRExponentialFunction exponentialFunction;
	CGFloat noncausticRGBA[4];
	CGFloat causticRGBA[4];
	struct
	{
		CGFloat reflectionPower;
		CGFloat startingWhite;
		CGFloat endingWhite;
		// Note, Matt's initial and final white has become starting and ending
		// white. This small adjustment to nomenclature aligns the
		// implementation with Apple's NSGradient which uses starting and ending
		// colour to describe initial and final colour co-ordinates (see the
		// -initWithStartingColor:startingColor endingColor:endingColor instance
		// method).
		// White origin and extent optimise the shader's internal
		// computations. Exponential output range for gloss maps to white
		// linearly. Linear mapping requires one factor for multiplication and
		// one offset for addition.
		CGFloat whiteOrigin;
		CGFloat whiteExtent;
	}
	gloss;
};

void RRGlossCausticShaderEvaluate(void *info, const CGFloat *in, CGFloat *out);

//------------------------------------------------------------------------------

@implementation RRGlossCausticShader

- (id)init
{
	if ((self = [super init]))
	{
		info = NSZoneMalloc([self zone], sizeof(*info));
		RRExponentialFunctionSetCoefficient(&info->exponentialFunction, 1.2f);
		info->gloss.reflectionPower = 0.2f;
		info->gloss.startingWhite = 0.6f;
		info->gloss.endingWhite = 0.2f;
		matcher = [[RRCausticColorMatcher alloc] init];
		[self setNoncausticColor:[NSColor grayColor]];
		[self update];
	}
	return self;
}
- (void)dealloc
{
	[matcher release];
	NSZoneFree([self zone], info);
	[super dealloc];
}

- (void)drawShadingFromPoint:(NSPoint)startingPoint toPoint:(NSPoint)endingPoint inContext:(CGContextRef)aContext
{
	// Interestingly, even surprisingly, caching the function object does not
	// work. The implementation could easily save the CGFunctionRef in-between
	// invocations. Trouble is: it does not work. The first invocation runs the
	// shader function, but subsequent invocations do not. Strange but true. Is
	// there something about Core Graphics Functions that allow single
	// executions only?
	static const CGFloat domain[] =
	{
		0.0f, 1.0f,
	};
	static const CGFloat range[] =
	{
		0.0f, 1.0f,
		0.0f, 1.0f,
		0.0f, 1.0f,
		0.0f, 1.0f,
	};
	const CGFunctionCallbacks callbacks =
	{
		0, // version
		RRGlossCausticShaderEvaluate, // evaluate
		NULL, // releaseInfo
	};
#define DIMENSION(v) (sizeof(v)/sizeof((v)[0]))
	CGFunctionRef evaluateFunction = CGFunctionCreate(info, DIMENSION(domain)/2, domain, DIMENSION(range)/2, range, &callbacks);
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGShadingRef shading = CGShadingCreateAxial(colorSpace, NSPointToCGPoint(startingPoint), NSPointToCGPoint(endingPoint), evaluateFunction, false, false);
	CGContextDrawShading(aContext, shading);
	CGShadingRelease(shading);
	CGColorSpaceRelease(colorSpace);
	CGFunctionRelease(evaluateFunction);
}

- (void)update
{
	[self willChangeValueForKey:@"color"];
	
	// (non-caustic RGBA --> caustic RGBA)
	[[[matcher matchForColor:[self noncausticColor]] colorUsingColorSpace:[NSColorSpace deviceRGBColorSpace]] getComponents:info->causticRGBA];
	
	// (non-caustic RGBA, gloss reflection power, starting and ending white -->
	// gloss white origin, extent)
	// Glossing depends on four variables: the non-caustic colour, the gloss
	// reflection power, starting white level and ending white level. Gloss
	// power applies to the non-caustic colour luminance.
	CGFloat gloss = powf(RRLuminanceFromRGBComponents(info->noncausticRGBA), info->gloss.reflectionPower);
	info->gloss.whiteOrigin = info->gloss.startingWhite*gloss;
	info->gloss.whiteExtent = info->gloss.endingWhite*gloss - info->gloss.whiteOrigin;
	
	[self didChangeValueForKey:@"color"];
}

#pragma mark Setters

//	exponential coefficient
//	non-caustic RGBA
//	gloss reflection power
//	gloss initial white level
//	gloss final white level

- (void)setExponentialCoefficient:(float)c
{
	RRExponentialFunctionSetCoefficient(&info->exponentialFunction, c);
}
- (void)setNoncausticColor:(NSColor *)aColor
{
	[[aColor colorUsingColorSpace:[NSColorSpace deviceRGBColorSpace]] getComponents:info->noncausticRGBA];
}
- (void)setGlossReflectionPower:(CGFloat)powerLevel
{
	info->gloss.reflectionPower = powerLevel;
}
- (void)setGlossStartingWhite:(CGFloat)whiteLevel
{
	info->gloss.startingWhite = whiteLevel;
}
- (void)setGlossEndingWhite:(CGFloat)whiteLevel
{
	info->gloss.endingWhite = whiteLevel;
}

#pragma mark Getters

- (float)exponentialCoefficient
{
	return info->exponentialFunction.coefficient;
}
- (NSColor *)noncausticColor
{
	return [NSColor colorWithDeviceRed:info->noncausticRGBA[0] green:info->noncausticRGBA[1] blue:info->noncausticRGBA[2] alpha:info->noncausticRGBA[3]];
}
- (CGFloat)glossReflectionPower
{
	return info->gloss.reflectionPower;
}
- (CGFloat)glossStartingWhite
{
	return info->gloss.startingWhite;
}
- (CGFloat)glossEndingWhite
{
	return info->gloss.endingWhite;
}

@synthesize matcher;

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key
{
	BOOL automatically;
	if ([key isEqualToString:@"color"])
	{
		automatically = NO;
	}
	else
	{
		automatically = [super automaticallyNotifiesObserversForKey:key];
	}
	return automatically;
}

@end

//------------------------------------------------------------------------------

void RRGlossCausticShaderEvaluate(void *info, const CGFloat *in, CGFloat *out)
{
#define INFO(x) (((struct RRGlossCausticShaderInfo *)info)->x)
	CGFloat x = *in;
	if (x < 0.5f)
	{
		int i;
		// 0<=x<0.5
		// 0<=2x<1
		CGFloat f = RRExponentialFunctionEvaluate(&INFO(exponentialFunction), 2*x)*INFO(gloss.whiteExtent) + INFO(gloss.whiteOrigin);
		CGFloat g = 1 - f;
		// f: 0 --> 1
		// g: 1 --> 0
		for (i = 0; i < 4; i++)
		{
			out[i] = INFO(noncausticRGBA)[i]*g + f;
		}
	}
	else
	{
		int i;
		// 0.5<=x<1
		// 0<=2(x-0.5)<1
		CGFloat f = RRExponentialFunctionEvaluate(&INFO(exponentialFunction), 2*(x - 0.5f));
		CGFloat g = 1 - f;
		// f: 0 --> 1
		// g: 1 --> 0
		for (i = 0; i < 4; i++)
		{
			out[i] = INFO(noncausticRGBA)[i]*g + INFO(causticRGBA)[i]*f;
		}
	}
}
