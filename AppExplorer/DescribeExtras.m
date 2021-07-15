// Copyright (c) 2021 Simon Fell
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

#import "DescribeExtras.h"
#import <objc/runtime.h>
#import "CaseInsensitiveStringKey.h"
#import "SoqlToken.h"
#import "Completion.h"

@implementation ZKDescribeSObject (Relationships)

-(NSDictionary<CaseInsensitiveStringKey*,ZKDescribeField*>*)parentRelationshipsByName {
    NSDictionary<CaseInsensitiveStringKey*,ZKDescribeField*>* r = objc_getAssociatedObject(self, @selector(parentRelationshipsByName));
    if (r == nil) {
        NSMutableDictionary<CaseInsensitiveStringKey*,ZKDescribeField*>* pr = [NSMutableDictionary dictionary];
        for (ZKDescribeField *f in self.fields) {
            if (f.relationshipName.length > 0 && f.referenceTo.count > 0) {
                [pr setObject:f forKey:[CaseInsensitiveStringKey of:f.relationshipName]];
            }
        }
        r = pr;
        objc_setAssociatedObject(self, @selector(parentRelationshipsByName), r, OBJC_ASSOCIATION_RETAIN);
    }
    return r;
}

-(NSDictionary<CaseInsensitiveStringKey*,ZKChildRelationship*>*)childRelationshipsByName {
    NSDictionary<CaseInsensitiveStringKey*,ZKChildRelationship*>* r = objc_getAssociatedObject(self, @selector(childRelationshipsByName));
    if (r == nil) {
        NSMutableDictionary<CaseInsensitiveStringKey*,ZKChildRelationship*>* cr = [NSMutableDictionary dictionaryWithCapacity:self.childRelationships.count];
        for (ZKChildRelationship *r in self.childRelationships) {
            if (r.relationshipName.length > 0) {
                [cr setObject:r forKey:[CaseInsensitiveStringKey of:r.relationshipName]];
            }
        }
        r = cr;
        objc_setAssociatedObject(self, @selector(childRelationshipsByName), r, OBJC_ASSOCIATION_RETAIN);
    }
    return r;
}

@end

@implementation ZKDescribeSObject (Completions)
-(NSArray<Completion*>*)parentRelCompletions {
    NSArray<Completion*> *comps = objc_getAssociatedObject(self, @selector(parentRelCompletions));
    if (comps == nil) {
        comps = [Completion completions:[self.parentRelationshipsByName.allValues valueForKey:@"relationshipName"] type:TTRelationship];
        for (Completion *c in comps) {
            c.finalInsertionText = [NSString stringWithFormat:@"%@.Id", c.finalInsertionText];
            c.onFinalInsert = ^BOOL(ZKTextView *tv, id<ZKTextViewCompletion> c) {
                // This selects the 'Id' we just inserted so that the user can start typing and it'll replace the Id.
                // otherwise typing starts after the Id.
                NSRange sel = tv.selectedRange;
                sel.location -= 2;
                sel.length += 2;
                tv.selectedRange = sel;
                [tv showPopup];
                return TRUE;
            };
        }
        objc_setAssociatedObject(self, @selector(parentRelCompletions), comps, OBJC_ASSOCIATION_RETAIN);
    }
    return comps;
}
@end

@implementation ZKDescribeField (Completion)
-(Completion*)completion {
    Completion *c = objc_getAssociatedObject(self, @selector(completion));
    if (c == nil) {
        c = [Completion txt:self.name type:TTField];
        objc_setAssociatedObject(self, @selector(completion), c, OBJC_ASSOCIATION_RETAIN);
    }
    return c;
}
@end
