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

#import "ColorizerStyle.h"

static ColorizerStyle *style;

@implementation ColorizerStyle

+(void)initialize {
    style = [ColorizerStyle new];
}

+(instancetype)styles {
    return style;
}

-(instancetype)init {
    self = [super init];
    // In unit tests the main bundle is the test runner bundle, not our bundle so it doesn't find the colors
    // so we do this dance to load the colors from an explict bundle.
    NSBundle *b = [NSBundle bundleForClass:self.class];
    self.keywordColor = [NSColor colorNamed:@"soql.keyword" bundle:b];
    self.fieldColor   = [NSColor colorNamed:@"soql.field"   bundle:b];
    self.funcColor    = [NSColor colorNamed:@"soql.func"    bundle:b];
    self.sobjectColor = [NSColor colorNamed:@"soql.sobject" bundle:b];
    self.relColor     = [NSColor colorNamed:@"soql.rel"     bundle:b];
    self.aliasColor   = [NSColor colorNamed:@"soql.alias"   bundle:b];
    self.literalColor = [NSColor colorNamed:@"soql.literal" bundle:b];
    NSColor *errColor = [NSColor colorNamed:@"soql.error"   bundle:b];
    
    self.underlined = @{NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle),
                        NSUnderlineColorAttributeName: errColor};
    
    self.keyword = @{ NSForegroundColorAttributeName:self.keywordColor};
    self.field   = @{ NSForegroundColorAttributeName:self.fieldColor};
    self.func    = @{ NSForegroundColorAttributeName:self.funcColor};
    self.sobject = @{ NSForegroundColorAttributeName:self.sobjectColor};
    self.alias   = @{ NSForegroundColorAttributeName:self.aliasColor};
    self.literal = @{ NSForegroundColorAttributeName:self.literalColor};
    self.relationship = @{ NSForegroundColorAttributeName:self.relColor};
    return self;
}
@end
