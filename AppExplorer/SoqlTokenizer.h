//
//  SoqlTokenizer.h
//  AppExplorer
//
//  Created by Simon Fell on 4/17/21.
//

#import <Foundation/Foundation.h>
#import "Describer.h"

@class Tokens;
@class ZKDescribeSObject;
@class DescribeListDataSource;
@class ZKTextView;

@protocol TokenizerDescriber
-(ZKDescribeSObject*)describe:(NSString*)obj;   // returns the describe if we have it?
-(BOOL)knownSObject:(NSString*)obj;             // is the object in the describeGlobal list of objects?
-(NSArray<NSString*>*)allQueryableSObjects;
-(NSImage *)iconForSObject:(NSString *)type;
@end

@interface DLDDescriber : NSObject<TokenizerDescriber, DescriberDelegate>
+(instancetype)describer:(DescribeListDataSource *)describes;
@property (copy,nonatomic) void(^onNewDescribe)(void);
@end

@interface SoqlTokenizer : NSObject<NSTextViewDelegate, NSTextStorageDelegate>
@property (strong,nonatomic) id<TokenizerDescriber> describer;
@property (strong,nonatomic) ZKTextView *view;
-(void)color;
// for testing
-(Tokens*)parseAndResolve:(NSString*)soql;
-(void)setDebugOutputTo:(NSString*)filename;
@end
