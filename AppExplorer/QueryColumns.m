// Copyright (c) 2020 Simon Fell
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

#import "QueryColumns.h"
#import <ZKSforce/ZKSObject.h>
#import <ZKSforce/ZKLocation.h>
#import <ZKSforce/ZKAddress.h>
#import <ZKSforce/ZKQueryResult.h>
#import "SearchQueryResult.h"

@interface QueryColumn : NSObject {
    NSString                     *name;
    NSMutableArray<QueryColumn*> *childCols;
}
@end

@implementation QueryColumn

-(instancetype)initWithName:(NSString *)n {
    self = [super init];
    name = [n copy];
    childCols = nil;
    return self;
}


+(QueryColumn *)columnWithName:(NSString *)name {
    return [[QueryColumn alloc] initWithName:name];
}

-(NSString *)debugDescription {
    return [NSString stringWithFormat:@"%@ [%@]", name, [childCols debugDescription]];
}

-(NSString *)name {
    return name;
}

-(BOOL)isEqual:(id)anObject {
    return [name isEqualToString:[anObject name]];
}

-(void)addChildCol:(QueryColumn *)c {
    if (childCols == nil) {
        childCols = [NSMutableArray array];
        [childCols addObject:c];
        return;
    }
    NSInteger idx = [childCols indexOfObject:c];
    if (idx == NSNotFound) {
        [childCols addObject:c];
    } else {
        QueryColumn *existing = childCols[idx];
        [existing addChildCol:c];
    }
}

-(void)addChildCols:(NSArray<QueryColumn*> *)cols {
    for (QueryColumn *c in cols)
        [self addChildCol:c];
}

-(void)addChildColWithNames:(NSArray<NSString*> *)childNames {
    for (NSString *cn in childNames) {
        [self addChildCol:[QueryColumn columnWithName:[name stringByAppendingFormat:@".%@", cn]]];
    }
}

-(NSArray<NSString*> *)allNames {
    if (childCols == nil) return @[name];
    NSMutableArray *c = [NSMutableArray arrayWithCapacity:childCols.count];
    for (QueryColumn *qc in childCols)
        [c addObjectsFromArray:[qc allNames]];
    return c;
}

-(BOOL)hasChildNames {
    return childCols != nil;
}

@end

@implementation QueryColumns

// looks to see if the queryColumn already exists in the columns collection, its returned if it is
// otherwise it's added to the collection.
// so in either case, the return value is the QueryColumn instance that is in the columns collection.
+ (QueryColumn *)getOrAddQueryColumn:(QueryColumn *)qc fromList:(NSMutableArray *)columns {
    NSUInteger idx = [columns indexOfObject:qc];
    if (idx == NSNotFound) {
        [columns addObject:qc];
        return qc;
    }
    return columns[idx];
}

+ (BOOL)addColumnsFromSObject:(ZKSObject *)row withPrefix:(NSString *)prefix toList:(NSMutableArray *)columns {
    BOOL seenNull = NO;
    
    for (NSString *fn in [row orderedFieldNames]) {
        NSObject *val = [row fieldValue:fn];
        if (val == nil || val == [NSNull null]) {
            seenNull = YES;
        }
        NSString *fullName = prefix.length > 0 ? [NSString stringWithFormat:@"%@.%@", prefix, fn] : fn;
        QueryColumn *qc = [QueryColumns getOrAddQueryColumn:[QueryColumn columnWithName:fullName] fromList:columns];
        if ([val isKindOfClass:[ZKAddress class]]) {
            if (![qc hasChildNames])
                [qc addChildColWithNames:@[@"street", @"city", @"state", @"stateCode", @"country", @"countryCode", @"postalCode", @"longitude", @"latitude"]];

        } else if ([val isKindOfClass:[ZKLocation class]]) {
            if (![qc hasChildNames])
                [qc addChildColWithNames:@[@"longitude", @"latitude"]];

        } else if ([val isKindOfClass:[ZKSObject class]]) {
            // different rows might have different sets of child fields populated, so we have to look at all
            // the rows, until we see a full row.
            NSMutableArray *relatedColumns = [NSMutableArray array];
            seenNull |= [QueryColumns addColumnsFromSObject:(ZKSObject *)val withPrefix:fullName toList:relatedColumns];
            [qc addChildCols:relatedColumns];
        }
    }
    return seenNull;
}

- (NSArray *)buildColumnListFromQueryResult:(ZKQueryResult *)qr {
    NSMutableArray *columns = [NSMutableArray array];
    NSMutableSet *processedTypes = [NSMutableSet set];
    BOOL isSearchResult = [qr conformsToProtocol:@protocol(IsSearchQueryResult)];
    
    for (ZKSObject *row in [qr records]) {
        // in the case we're looking at search results, we need to get columns for each distinct type.
        if ([processedTypes containsObject:[row type]]) continue;
        
        // if we didn't see any null columns, then there's no need to look at any further rows.
        if (![QueryColumns addColumnsFromSObject:row withPrefix:nil toList:columns]) {
            if (!isSearchResult) break; // all done.
            [processedTypes addObject:[row type]];
        }
    }
    // now flatten the queryColumns into a set of real columns
    NSMutableArray *colNames = [NSMutableArray arrayWithCapacity:columns.count + 1];

    for (QueryColumn *qc in columns)
        [colNames addObjectsFromArray:[qc allNames]];
        
    return colNames;
}


-(instancetype)initWithResult:(ZKQueryResult*)qr {
    self = [super init];
    self.names = [self buildColumnListFromQueryResult:qr];
    self.isSearchResult = [qr conformsToProtocol:@protocol(IsSearchQueryResult)];
    return self;
}

@end


