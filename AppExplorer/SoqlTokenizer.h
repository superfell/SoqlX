//
//  SoqlTokenizer.h
//  AppExplorer
//
//  Created by Simon Fell on 4/17/21.
//

#import <Foundation/Foundation.h>

@class ZKDescribeSObject;
@class DescribeListDataSource;

@protocol Describer
-(ZKDescribeSObject*)describe:(NSString*)obj;   // returns the describe if we have it?
-(BOOL)knownSObject:(NSString*)obj;             // is the object in the describeGlobal list of objects?
-(NSArray<NSString*>*)allQueryableSObjects;
@end



@interface SoqlTokenizer : NSObject<Describer, NSTextViewDelegate, NSTextStorageDelegate>
@property (strong,nonatomic) DescribeListDataSource* describes;
@property (strong,nonatomic) NSTextView *view;
-(void)color;
@end


