// RRUtils RRGlossCausticShader.h
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

#import <AppKit/AppKit.h>

@class RRCausticColorMatcher;

@interface RRGlossCausticShader : NSObject
{
	struct RRGlossCausticShaderInfo *info;
	RRCausticColorMatcher *matcher;
}

- (void)drawShadingFromPoint:(NSPoint)startingPoint toPoint:(NSPoint)endingPoint inContext:(CGContextRef)aContext;

- (void)update;
	// Send -update after changing one or more parameters. Setters do not
	// automatically update the shader. This is by design. It applies to the
	// caustic colour matcher too. Change anything? Send an update. Otherwise,
	// if the setters automatically update, multiple changes trigger unnecessary
	// multiple updates. It's a small optimisation.
	// Updating follows the dependency chain. Caustic colour depends on
	// non-caustic colour along with all the caustic colour matcher's tuneable
	// configuration settings. Updating also re-computes the gloss. Gloss
	// derives from non-caustic colour luminance, among other things.

//---------------------------------------------------------------------- setters

- (void)setExponentialCoefficient:(float)c;
- (void)setNoncausticColor:(NSColor *)aColor;
	// Converts aColor to device RGB colour space. The resulting colour
	// components become the new non-caustic colour. This setter, like all
	// others, does not automatically readjust the dependencies. Invoke -update
	// after adjusting one or more settings.
- (void)setGlossReflectionPower:(CGFloat)powerLevel;
	// Assigns a new power level to the gloss reflection.
- (void)setGlossStartingWhite:(CGFloat)whiteLevel;
	// White levels range between 0 and 1 inclusive. Gloss starting white levels
	// typically have higher values compared to ending white level.
- (void)setGlossEndingWhite:(CGFloat)whiteLevel;

//---------------------------------------------------------------------- getters

- (float)exponentialCoefficient;
- (NSColor *)noncausticColor;
	// Returns the non-caustic colour.
- (CGFloat)glossReflectionPower;
- (CGFloat)glossStartingWhite;
- (CGFloat)glossEndingWhite;

// Key-value coding automatically gives access to colour matching for caustic
// colours. Special note though, changing caustic matcher thresholds does not
// (repeat not) automatically adjust the shader's caustic colour. You need to
// update the shader when ready.
// Currently, the matcher property offers read-only access. You cannot set the
// matcher! However, perhaps future versions will allow setting in order to
// override the default caustic matching behaviour. Developers might want to
// customise the colour matching algorithmically as well as by tweaking
// parameters.
@property(readonly) RRCausticColorMatcher *matcher;

@end
