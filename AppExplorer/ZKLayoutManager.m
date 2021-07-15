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

#import "ZKLayoutManager.h"

@implementation ZKLayoutManager

-(void)underlineGlyphRange:(NSRange)glyphRange
             underlineType:(NSUnderlineStyle)underlineVal
          lineFragmentRect:(NSRect)lineRect
    lineFragmentGlyphRange:(NSRange)lineGlyphRange
           containerOrigin:(NSPoint)o {

    // NSLayoutManager will not display any underlines on leading and trailing whitespace. We override this to defeat that
    // behavoir.
    //
    // The impl of underlineGlyphRange in NSLayoutManager specifies a +ve baselineOffset depending on the font size.
    // I have no idea where it gets it from, its not [self defaultBaselineOffsetForFont:f]. You can observe this by seeing
    // what baselineOffset is in drawUnderlineForGlyphRange and calling the super version of underlineGlyphRange.
    // It also appears that this is ignored. It doesn't seem to matter what the value is the underline always appears at
    // the same place.
    [self drawUnderlineForGlyphRange:glyphRange
                       underlineType:underlineVal
                      baselineOffset:0
                    lineFragmentRect:lineRect
              lineFragmentGlyphRange:lineGlyphRange
                     containerOrigin:o];
}

@end
