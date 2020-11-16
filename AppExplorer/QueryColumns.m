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

@property (assign) BOOL hasSeenValue;

@end

@implementation QueryColumn

-(instancetype)initWithName:(NSString *)n {
    self = [super init];
    name = [n copy];
    childCols = nil;
    self.hasSeenValue = NO;
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

-(QueryColumn*)getOrAddQueryColumn:(NSString *)name {
    for (QueryColumn *c in childCols) {
        if ([c.name isEqualToString:name]) {
            return c;
        }
    }
    if (childCols == nil) {
        childCols = [NSMutableArray array];
    }
    QueryColumn *c = [QueryColumn columnWithName:name];
    [childCols addObject:c];
    return c;
}

-(void)addChildColWithNames:(NSArray<NSString*>*)names {
    for (NSString *n in names) {
        [self getOrAddQueryColumn:n].hasSeenValue = YES;
    }
}

-(void)addNamesTo:(NSMutableArray<NSString*>*)dest {
    if (name.length > 0 && childCols.count == 0) {
        [dest addObject:name];
    }
    for (QueryColumn *c in childCols) {
        [c addNamesTo:dest];
    }
}

-(NSArray<NSString*> *)allNames {
    NSMutableArray *n = [NSMutableArray array];
    [self addNamesTo:n];
    return n;
}

-(BOOL)hasChildNames {
    return childCols.count > 0;
}

-(BOOL)allHaveSeenValues {
    if (childCols.count == 0) {
        return self.hasSeenValue;
    }
    for (QueryColumn *c in childCols) {
        if (!c.allHaveSeenValues) {
            return NO;
        }
    }
    return YES;
}

@end

@implementation QueryColumns

+(void)addColumnsFromSObject:(ZKSObject *)row withPrefix:(NSString *)prefix to:(QueryColumn *)parent {
    for (NSString *fn in [row orderedFieldNames]) {
        NSString *fullName = prefix.length > 0 ? [NSString stringWithFormat:@"%@.%@", prefix, fn] : fn;
        QueryColumn *qc = [parent getOrAddQueryColumn:fullName];
        NSObject *val = [row fieldValue:fn];
        if (!(val == nil || val == [NSNull null])) {
            qc.hasSeenValue = YES;
        }
        if ([val isKindOfClass:[ZKAddress class]]) {
            if (![qc hasChildNames])
                [qc addChildColWithNames:@[@"street", @"city", @"state", @"stateCode", @"country", @"countryCode", @"postalCode", @"longitude", @"latitude"]];

        } else if ([val isKindOfClass:[ZKLocation class]]) {
            if (![qc hasChildNames])
                [qc addChildColWithNames:@[@"longitude", @"latitude"]];

        } else if ([val isKindOfClass:[ZKSObject class]]) {
            [QueryColumns addColumnsFromSObject:(ZKSObject *)val withPrefix:fullName to:qc];
        }
    }
}

-(instancetype)initWithResult:(ZKQueryResult*)qr {
    self = [super init];
    
    QueryColumn *root = [[QueryColumn alloc] initWithName:@""];
    NSMutableSet *processedTypes = [NSMutableSet set];
    BOOL isSearchResult = [qr conformsToProtocol:@protocol(IsSearchQueryResult)];
    
    for (ZKSObject *row in [qr records]) {
        // in the case we're looking at search results, we need to get columns for each distinct type.
        if ([processedTypes containsObject:[row type]]) continue;
        
        // if we didn't see any null columns, then there's no need to look at any further rows.
        self.rowsChecked++;
        [QueryColumns addColumnsFromSObject:row withPrefix:nil to:root];
        if (root.allHaveSeenValues) {
            if (!isSearchResult) break; // all done.
            [processedTypes addObject:[row type]];
        }
    }
    // now flatten the queryColumns into a set of real columns
    self.names = [root allNames];
    self.isSearchResult = isSearchResult;
    return self;
}

@end


