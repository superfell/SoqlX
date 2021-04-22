// Copyright (c) 2016,2021 Simon Fell
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

#import "ZKTextView.h"
#include <mach/mach_time.h>

double ticksToMilliseconds;

@interface ZKTextView()
@property (strong,nonatomic) NSTimer *idleCheckTimer;
@property (strong,nonatomic) NSArray<NSString*>* completions;
@end

@implementation ZKTextView

+(void)initialize {
    // The first time we get here, ask the system
    // how to convert mach time units to nanoseconds
    mach_timebase_info_data_t timebase;
    // to be completely pedantic, check the return code of this next call.
    mach_timebase_info(&timebase);
    ticksToMilliseconds = (double)timebase.numer / timebase.denom / 1000000;
}

- (instancetype)initWithFrame:(NSRect)frameRect textContainer:(nullable NSTextContainer *)container {
    self = [super initWithFrame:frameRect textContainer:container];
    self.idleCheckTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(checkIdle) userInfo:nil repeats:YES];
    hasTyped = FALSE;
    return self;
}

-(nullable instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    self.idleCheckTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(checkIdle) userInfo:nil repeats:YES];
    hasTyped = FALSE;
    return self;
}

-(instancetype)init {
    self = [super init];
    self.idleCheckTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(checkIdle) userInfo:nil repeats:YES];
    hasTyped = FALSE;
    return self;
}

-(void)awakeFromNib {
    self.table.dataSource = self;
    self.table.delegate = self;
    //self.table.rowHeight = 21;
    self.table.usesAutomaticRowHeights = YES;
    self.table.refusesFirstResponder = YES;
    self.table.selectionHighlightStyle = NSTableViewSelectionHighlightStyleSourceList;
    self.tableScollView.verticalScroller.controlSize = NSControlSizeRegular;
}

// if the user pastes rich text, we want to treat it as plain text becuase
// we're controlling the formatting
-(void)paste:(id)sender {
    [self pasteAsPlainText:sender];
}

-(void)mouseMoved:(NSEvent *)event {
    lastEvent = mach_absolute_time();
    [super mouseMoved:event];
}

-(void)keyDown:(NSEvent *)event {
    lastEvent = mach_absolute_time();
    if (self.po.shown) {
        NSString *theArrow = [event charactersIgnoringModifiers];
        if ( [theArrow length] == 1 ) {
            unichar keyChar = [theArrow characterAtIndex:0];
            NSLog(@"keyChar %d", keyChar);
            BOOL isFinal = NO;
            NSTextMovement movement;
            switch (keyChar) {
                case NSUpArrowFunctionKey:
                case NSDownArrowFunctionKey:
                case NSPageUpFunctionKey:
                case NSPageDownFunctionKey:
                    NSLog(@"Passing keyDown to table");
                    [self.table keyDown:event];
                    isFinal = NO;
                    movement = NSTextMovementUp;
                    break;
                case NSTabCharacter:
                    isFinal = YES;
                    movement = NSTextMovementTab;
                    break;
                case NSCarriageReturnCharacter: {
                    isFinal = YES;
                    movement = NSTextMovementReturn;
                    break;
                default:
                    hasTyped = TRUE;
                    [super keyDown:event];
                }
            }
            NSInteger row = [self.table selectedRow];
            if (row >= 0) {
                NSString *c = self.completions[row];
                [self insertCompletion:c forPartialWordRange:self.rangeForUserCompletion movement:movement isFinal:isFinal];
                if (isFinal) {
                    [self.po performClose:self];
                }
            }
            return;
        }
    }
    hasTyped = TRUE;
    [super keyDown:event];
}

-(void)showPopup {
    NSRange sel = [self selectedRange];
    NSRange theTextRange = [[self layoutManager] glyphRangeForCharacterRange:sel actualCharacterRange:NULL];
    NSRect layoutRect = [[self layoutManager] boundingRectForGlyphRange:theTextRange inTextContainer:[self textContainer]];
    NSPoint containerOrigin = [self textContainerOrigin];
    layoutRect.origin.x += containerOrigin.x;
    layoutRect.origin.y += containerOrigin.y;
    layoutRect.size.width +=2;
    [self.po showRelativeToRect:layoutRect ofView:self preferredEdge:NSRectEdgeMinY];
}

-(BOOL)isAtEndOfWord {
    NSRange r = [self selectedRange];
    if (r.location == 0) {
        return FALSE;
    }
    if (r.location == self.textStorage.length) {
        return TRUE;
    }
    NSString *txt = self.textStorage.string;
    unichar prev = [txt characterAtIndex:r.location-1];
    unichar next = [txt characterAtIndex:r.location];
    return (isblank(next) || next==',') && !isblank(prev);
}

-(void)checkIdle {
    uint64_t now = mach_absolute_time();
    double idle = (now-lastEvent) * ticksToMilliseconds;
    if (hasTyped && (idle > 400)) {
        lastEvent = now;
        hasTyped = FALSE;
        if ([self isAtEndOfWord]) {
            NSInteger sel = -1;
            self.completions = [self.delegate textView:self completions:[NSArray array] forPartialWordRange:[self rangeForUserCompletion] indexOfSelectedItem:&sel];
            [self.table reloadData];
            if (self.completions.count > 0) {
                [self.table scrollRowToVisible:0];
                [self.table selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];
                [self showPopup];
            }
        }
    }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.completions.count;
}

- (NSView *)tableView:(NSTableView *)tableView
   viewForTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)row {
 
    // Get an existing cell with the MyView identifier if it exists
    NSTextField *result = [tableView makeViewWithIdentifier:@"MyView" owner:self];
 
    // There is no existing cell to reuse so create a new one
    if (result == nil) {
        // Create the new NSTextField with a frame of the {0,0} with the width of the table.
        // Note that the height of the frame is not really relevant, because the row height will modify the height.
        result = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 100, 10)];
        result.editable = NO;
        result.textColor = [NSColor whiteColor];
        result.font = [NSFont fontWithName:@"Arial" size:14];
        result.bordered = NO;
        result.drawsBackground = NO;
        result.maximumNumberOfLines = 1;
        
        // The identifier of the NSTextField instance is set to MyView.
        // This allows the cell to be reused.
        result.identifier = @"MyView";
    }

    // result is now guaranteed to be valid, either as a reused cell
    // or as a new cell, so set the stringValue of the cell to the
    // nameArray value at row
    if ([tableColumn.identifier isEqual:@"text"]) {
        result.stringValue = self.completions[row];
    } else {
        result.stringValue = @"";
    }

    // Return the result
    return result;
}

@end
