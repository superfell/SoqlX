// Copyright (c) 2012 Simon Fell
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

#import "SearchQueryResult.h"
#import "ZKSObject.h"
#import "ZKQueryResult+NSTableView.h"

@implementation SearchQueryResult

+(instancetype)searchQueryResults:(NSArray *)searchResults {
    return [[[SearchQueryResult alloc] initWithRecords:searchResults size:searchResults.count done:TRUE queryLocator:nil] autorelease];
}

- (id)tableView:(NSTableView *)view objectValueForTableColumn:(NSTableColumn *)tc row:(int)rowIdx {
    // handle the SObject__Type column used in search results.
    if ([tc.identifier isEqualToString:@"SObject__Type"]) {
        ZKSObject *r = records[rowIdx];
        return [r type];
    }
    return [super tableView:view objectValueForTableColumn:tc row:rowIdx];
}

@end
