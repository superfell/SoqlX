// Copyright (c) 2006-2014,2018,2020 Simon Fell
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

#import <Cocoa/Cocoa.h>
#import <ZKSforce/ZKSforce.h>
#import "IconProvider.h"
#import "Describer.h"

@class ZKSforceClient;
@class ZKDescribeSObject;
@class ZKDescribeField;
@class ZKDescribeGlobalTheme;

@interface DescribeListDataSource : NSObject<NSOutlineViewDataSource, NSOutlineViewDelegate, IconProvider, DescriberDelegate> {
    ZKSforceClient          *sforce;

    NSArray<ZKDescribeGlobalSObject*>                   *types;
    NSDictionary<NSString*,ZKDescribeGlobalSObject*>    *descGlobalSobjects;
    
    NSMutableDictionary<NSString*,ZKDescribeSObject*>           *describes;
    NSMutableDictionary<NSString*,NSArray<ZKDescribeField*>*>   *sortedDescribes;
    NSMutableDictionary<NSString*,NSImage*>                     *icons;
    NSSortDescriptor        *fieldSortOrder;

    NSString                            *filter;
    NSArray<ZKDescribeGlobalSObject*>   *filteredTypes;

    NSOutlineView           *outlineView;
}

- (void)addDelegate:(NSObject<DescriberDelegate>*)d;

- (void)setSforce:(ZKSforceClient *)sf;
- (void)setTypes:(ZKDescribeGlobalTheme *)t view:(NSOutlineView *)ov;
- (void)refreshDescribes:(ZKDescribeGlobalTheme*)t view:(NSOutlineView *)ov;
- (void)stopBackgroundDescribe;

// access/trigger the desc cache
- (void)describe:(NSString *)type
       failBlock:(ZKFailWithErrorBlock)failBlock
   completeBlock:(ZKCompleteDescribeSObjectBlock)completeBlock;

- (void)enumerateDescribes:(NSArray<NSString*> *)types
                 failBlock:(ZKFailWithErrorBlock)failBlock
             describeBlock:(void(^)(ZKDescribeSObject *desc, BOOL isLast, BOOL *stop))describeBlock;

-(BOOL)isTypeDescribable:(NSString *)type;
-(BOOL)hasDescribe:(NSString *)type;
-(ZKDescribeSObject *)cachedDescribe:(NSString *)type;
-(void)prioritizeDescribe:(NSString *)type;
-(NSImage *)iconForType:(NSString *)sobjectName;

-(NSUInteger)describedCount;
-(NSUInteger)totalCount;

// filter the view
@property (copy) NSString *filter;

@property (readonly, copy) NSArray<ZKDescribeGlobalSObject*> *SObjects;

@end;

@interface Row : NSObject
@property NSObject *label;
@property NSString *val;
@property BOOL isEmpty;
+(instancetype) row:(NSString *)l val:(NSString*)v;
+(instancetype) titleRow:(NSAttributedString *)l val:(NSString*)v;
@end

// Base class that does most of the work for the SObject & Field details data sources
@interface DetailDataSource : NSObject<NSTableViewDataSource>
@property (copy) void (^onChange)(DetailDataSource*);
@end


@interface SObjectDataSource : DetailDataSource {
    ZKDescribeSObject    *sobject;
}
- (instancetype)initWithDescribe:(ZKDescribeSObject *)s NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end;


@interface SObjectFieldDataSource : DetailDataSource {
    ZKDescribeField        *field;
}
- (instancetype)initWithDescribe:(ZKDescribeField *)f NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end;

@interface NoSelection : NSObject {
}
@end
