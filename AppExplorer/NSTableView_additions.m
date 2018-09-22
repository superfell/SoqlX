// Copyright (c) 2015 Simon Fell
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

#import "NSTableView_additions.h"

@implementation NSTableView (ZKTableCopySupport)

-(void)zkCopyTableDataToClipboard {
    NSMutableString *d = [NSMutableString string];
    id<NSTableViewDataSource> ds = self.dataSource;
    int rows = [ds numberOfRowsInTableView:self];
    for (int r=0; r < rows; r++) {
        bool firstCol = YES;
        for (NSTableColumn *col in self.tableColumns) {
            if (!firstCol) {
                [d appendString:@"\t"];
            } else if (d.length > 0) {
                [d appendString:@"\n"];
            }
            NSObject *cv = [ds tableView:self objectValueForTableColumn:col row:r];
            NSString *sv = @"";
            if ([cv isKindOfClass:[NSString class]]) {
                sv = (NSString *)cv;
            } else if ([cv isKindOfClass:[NSAttributedString class]]) {
                sv = ((NSAttributedString *)cv).string;
            } else {
                sv = cv.description;
            }
            if (sv.length > 0)
                [d appendString:sv];
            firstCol = NO;
        }
    }
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb declareTypes:@[NSPasteboardTypeTabularText, NSPasteboardTypeString] owner:nil];
    [pb setString:d forType:NSPasteboardTypeTabularText];
    [pb setString:d forType:NSPasteboardTypeString];
}

@end
