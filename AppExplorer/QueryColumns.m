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
#import "ZKQueryResult+Display.h"

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

+(void)addColumnsFromSObject:(ZKSObject *)row
                  withPrefix:(NSString *)prefix
                        path:(NSMutableArray<NSString*>*)path
                          to:(QueryColumn *)parent
                  startAtRow:(NSInteger)startingRowIdx qr:(ZKQueryResult*)qr {
    
    for (NSString *fn in [row orderedFieldNames]) {
        NSString *fullName = fn;
        if (prefix.length > 0) {
            NSMutableString *n = [NSMutableString stringWithCapacity:prefix.length+1+fn.length];
            [n appendString:prefix];
            [n appendString:@"."];
            [n appendString:fn];
            fullName = [n copy];
        }
        QueryColumn *qc = [parent getOrAddQueryColumn:fullName];
        if ((!qc.hasChildNames) && (qc.hasSeenValue)) {
            continue;
        }
        // Check the rows for this column until we have an answer.
        [path addObject:fn];
        for (NSInteger rowIdx = startingRowIdx; rowIdx < qr.records.count; rowIdx++) {
            //NSLog(@"checking %@ row %ld", fullName, rowIdx);
            NSObject *val = [qr valueForFieldPathArray:path row:rowIdx];
            if ((val == nil || val == [NSNull null])) {
                continue;
            }
            if ([val isKindOfClass:[NSString class]]) {
                qc.hasSeenValue = YES;
                break;
            } else if ([val isKindOfClass:[ZKSObject class]]) {
                // we have to look at all rows for related sobjects due to typeof expressions
                // and possible nested related sobjects. But we only need to process each type
                // once.
                NSMutableSet *types = [NSMutableSet set];
                for (NSInteger nestedIdx = rowIdx; nestedIdx < qr.records.count; nestedIdx++) {
                    ZKSObject *sobj = (ZKSObject*)[qr valueForFieldPathArray:path row:nestedIdx];
                    if ((sobj != nil) && (![types containsObject:sobj.type])) {
                        [QueryColumns addColumnsFromSObject:sobj withPrefix:fullName path:path to:qc startAtRow:nestedIdx qr:qr];
                        [types addObject:sobj.type];
                    }
                }
                break;
            } else if ([[val class] respondsToSelector:@selector(wsdlSchema)]) {
                if (![qc hasChildNames]) {
                    NSArray<ZKComplexTypeFieldInfo*> *fields = [[[val class] wsdlSchema] fieldsIncludingParents];
                    if (fields.count > 1) {
                        NSArray<NSString*> *propertyNames = [fields valueForKey:@"propertyName"];
                        [qc addChildColsWithNames:propertyNames];
                    }
                    qc.hasSeenValue = YES;
                }
                break;
            } else {
                NSLog(@"unexpected type of %@ for %@ at row %ld", [val class], fullName, (long)rowIdx);
            }
        }
        [path removeLastObject];
    }
}

-(instancetype)initWithResult:(ZKQueryResult*)qr {
    self = [super init];
    
    self.root = [[QueryColumn alloc] initWithName:@""];
    NSMutableSet *processedTypes = [NSMutableSet set];
    BOOL isSearchResult = [qr conformsToProtocol:@protocol(IsSearchQueryResult)];
    
    NSMutableArray<NSString*>* path = [NSMutableArray arrayWithCapacity:5];
    for (ZKSObject *row in [qr records]) {
        // in the case we're looking at search results, we need to get columns for each distinct type.
        if ([processedTypes containsObject:[row type]]) continue;
        
        self.rowsChecked++;
        [path removeAllObjects];
        [QueryColumns addColumnsFromSObject:row withPrefix:nil path:path to:self.root startAtRow:0 qr:qr];
        if (!isSearchResult) break; // all done.
        [processedTypes addObject:[row type]];
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
