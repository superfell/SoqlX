//
//  SoqlParser.h
//  ZKParser
//
//  Created by Simon Fell on 4/9/21.
//  Copyright © 2021 Simon Fell. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Tokens;

// Keys used in the userInfo dictionary in errors.
extern NSString *KeyPosition;
extern NSString *KeyCompletions;

@interface SoqlParser : NSObject
-(Tokens*)parse:(NSString *)input error:(NSError**)err;
-(void)setDebugOutputTo:(NSString*)filename;
@end
