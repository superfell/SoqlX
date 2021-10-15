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
#import <ZKSforce/ZKComplexTypeFieldInfo.h>
#import "SearchQueryResult.h"

@interface QueryColumn : NSObject {
    NSString                     *name;
    NSMutableArray<QueryColumn*> *childCols;
    NSMutableDictionary<NSString*, QueryColumn*> *childrenByName;
}

@property (assign) BOOL hasSeenValue;

@end

@implementation QueryColumn

+(QueryColumn *)columnWithName:(NSString *)name {
    return [[QueryColumn alloc] initWithName:name];
}

-(instancetype)initWithName:(NSString *)n {
    self = [super init];
    name = n;
    return self;
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
    QueryColumn *e = childrenByName[name];
    if (e != nil) {
        return e;
    }
    if (childCols == nil) {
        childCols = [NSMutableArray array];
        childrenByName = [NSMutableDictionary dictionary];
    }
    QueryColumn *c = [QueryColumn columnWithName:name];
    [childCols addObject:c];
    childrenByName[name] = c;
    return c;
}

-(void)addChildColsWithNames:(NSArray<NSString*>*)names {
    for (NSString *n in names) {
        NSString *fn = name.length > 0 ? [NSString stringWithFormat:@"%@.%@", name, n] : n;
        [self getOrAddQueryColumn:fn].hasSeenValue = YES;
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
    NSMutableArray *n = [NSMutableArray arrayWithCapacity:childCols.count * 2];
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

@interface QueryColumns()
@property (retain) QueryColumn *root;
@end

@implementation QueryColumns

+(void)addColumnsFromSObject:(ZKSObject *)row withPrefix:(NSString *)prefix to:(QueryColumn *)parent {
    for (NSString *fn in [row orderedFieldNames]) {
        NSString *fullName = prefix.length > 0 ? [NSString stringWithFormat:@"%@.%@", prefix, fn] : fn;
        QueryColumn *qc = [parent getOrAddQueryColumn:fullName];
        if ((!qc.hasChildNames) && (qc.hasSeenValue)) {
            continue;
        }
        NSObject *val = [row fieldValue:fn];
        // we have to look at all rows for related sobjects
        if (prefix == nil && (!(val == nil || val == [NSNull null]))) {
            qc.hasSeenValue = YES;
        }
        if ((![qc hasChildNames]) && [[val class] respondsToSelector:@selector(wsdlSchema)]) {
            NSArray<ZKComplexTypeFieldInfo*> *fields = [[[val class] wsdlSchema] fieldsIncludingParents];
            if (fields.count > 1) {
                NSArray<NSString*> *propertyNames = [fields valueForKey:@"propertyName"];
                [qc addChildColsWithNames:propertyNames];
            }
        } else if ([val isKindOfClass:[ZKSObject class]]) {
            [QueryColumns addColumnsFromSObject:(ZKSObject *)val withPrefix:fullName to:qc];
        }
    }
}

-(instancetype)initWithResult:(ZKQueryResult*)qr {
    self = [super init];
    
    self.root = [[QueryColumn alloc] initWithName:@""];
    NSMutableSet *processedTypes = [NSMutableSet set];
    BOOL isSearchResult = [qr conformsToProtocol:@protocol(IsSearchQueryResult)];
    
    // TODO: rather than processing every column everytime, it should go across columns til it finds
    // a nil or child object, then go down just that column.
    
    for (ZKSObject *row in [qr records]) {
        // in the case we're looking at search results, we need to get columns for each distinct type.
        if ([processedTypes containsObject:[row type]]) continue;
        
        // if we didn't see any null columns, then there's no need to look at any further rows.
        self.rowsChecked++;
        [QueryColumns addColumnsFromSObject:row withPrefix:nil to:self.root];
        if (self.root.allHaveSeenValues) {
            if (!isSearchResult) break; // all done.
            [processedTypes addObject:[row type]];
        }
    }
    // now flatten the queryColumns into a set of real columns
    self.names = [self.root allNames];
    self.isSearchResult = isSearchResult;
    return self;
}

-(NSInteger)count {
    return self.names.count;
}

@end
