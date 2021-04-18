//
//  ColorizerStyle.m
//  AppExplorer
//
//  Created by Simon Fell on 4/17/21.
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
    self.fieldColor = [NSColor colorNamed:@"soql.field"];
    self.keywordColor = [NSColor colorNamed:@"soql.keyword"];
    self.literalColor = [NSColor colorNamed:@"soql.literal"];
    
    self.underlineStyle = @(NSUnderlineStyleSingle | NSUnderlinePatternDot | NSUnderlineByWord);
    self.underlined = @{
                        NSUnderlineStyleAttributeName: self.underlineStyle,
                        NSUnderlineColorAttributeName: [NSColor redColor],
                        };
    self.noUnderline = @{ NSUnderlineStyleAttributeName: @(NSUnderlineStyleNone) };
    
    // TODO, why is colorNamed:@ returning nil in unit tests?
    if (self.keywordColor != nil) {
        self.keyWord = @{ NSForegroundColorAttributeName:self.keywordColor, NSUnderlineStyleAttributeName: @(NSUnderlineStyleNone)};
        self.field =   @{ NSForegroundColorAttributeName:self.fieldColor,   NSUnderlineStyleAttributeName: @(NSUnderlineStyleNone)};
        self.literal = @{ NSForegroundColorAttributeName:self.literalColor, NSUnderlineStyleAttributeName: @(NSUnderlineStyleNone)};
    }
    return self;
}
@end
