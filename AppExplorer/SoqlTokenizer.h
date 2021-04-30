//
//  SoqlTokenizer.h
//  AppExplorer
//
//  Created by Simon Fell on 4/17/21.
//

#import <Foundation/Foundation.h>

@class Tokens;
@class ZKDescribeSObject;
@class DescribeListDataSource;

@protocol Describer
-(ZKDescribeSObject*)describe:(NSString*)obj;   // returns the describe if we have it?
-(BOOL)knownSObject:(NSString*)obj;             // is the object in the describeGlobal list of objects?
-(NSArray<NSString*>*)allQueryableSObjects;
-(NSImage *)iconForSObject:(NSString *)type;
@end

@interface DLDDescriber<Describer> : NSObject
+(id<Describer>)describer:(DescribeListDataSource *)describes;
@end

@interface SoqlTokenizer : NSObject<NSTextViewDelegate, NSTextStorageDelegate>
@property (strong,nonatomic) id<Describer> describer;
@property (strong,nonatomic) NSTextView *view;
-(void)color;
// for testing
-(Tokens*)parseAndResolve:(NSString*)soql;
@end
