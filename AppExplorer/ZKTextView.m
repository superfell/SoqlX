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
@property (strong,nonatomic) NSArray<id<ZKTextViewCompletion>>* completions;
@property (assign,nonatomic) BOOL awake;
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
    // tableView makeView will call awakeFromNib on the owner, which is us, but we only want to initialize the tableview once.
    if (!self.awake) {
        NSLog(@"awakeFromNib");
        self.table.dataSource = self;
        self.table.delegate = self;
        self.table.rowHeight = 24;
        self.table.refusesFirstResponder = YES;
        self.table.selectionHighlightStyle = NSTableViewSelectionHighlightStyleSourceList;
        self.tableScollView.verticalScroller.controlSize = NSControlSizeRegular;
        self.automaticTextCompletionEnabled = NO;
        self.awake = YES;
    }
}

// if the user pastes rich text, we want to treat it as plain text becuase
// we're controlling the formatting
-(void)paste:(id)sender {
    [self pasteAsPlainText:sender];
}

- (void)mouseDown:(NSEvent *)theEvent {
    NSPoint point = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    NSInteger charIndex = [self characterIndexForInsertionAtPoint:point];
    if (charIndex >= 0 && charIndex < self.textStorage.string.length) {
        NSRange attrRange;
        NSString *tooltip = [self.textStorage attribute:NSToolTipAttributeName atIndex:charIndex effectiveRange:&attrRange];
        if (tooltip != nil) {
            NSRange theTextRange = [[self layoutManager] glyphRangeForCharacterRange:attrRange actualCharacterRange:NULL];
            NSRect layoutRect = [[self layoutManager] boundingRectForGlyphRange:theTextRange inTextContainer:[self textContainer]];
            NSPoint containerOrigin = [self textContainerOrigin];
            layoutRect.origin.x += containerOrigin.x;
            layoutRect.origin.y += containerOrigin.y;
            layoutRect.size.width +=2;
            self.errorText.stringValue = tooltip;
            [self.errorPopover showRelativeToRect:layoutRect ofView:self preferredEdge:NSRectEdgeMaxY];
        }
    }
    [super mouseDown:theEvent];
}

-(void)mouseMoved:(NSEvent *)event {
    lastEvent = mach_absolute_time();
    [super mouseMoved:event];
}

-(void)keyDown:(NSEvent *)event {
    lastEvent = mach_absolute_time();
    if (self.completionsPopover.shown) {
        NSString *theArrow = [event charactersIgnoringModifiers];
        if ( [theArrow length] == 1 ) {
            unichar keyChar = [theArrow characterAtIndex:0];
            BOOL isFinal = NO;
            NSTextMovement movement;
            NSInteger pageAmount = 8;
            switch (keyChar) {
                case NSPageUpFunctionKey:
                    pageAmount = -8;
                case NSPageDownFunctionKey: {
                    NSInteger row = self.table.selectedRow;
                    row = MIN(MAX(0,row + pageAmount), self.table.numberOfRows-1);
                    [self.table selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
                    [self scrollRowToCenterVisible:row];
                    break;
                }
                case NSUpArrowFunctionKey:
                case NSDownArrowFunctionKey:
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
                case 27:    // escape key // left arrow // right arrow
                case NSLeftArrowFunctionKey:
                case NSRightArrowFunctionKey:
                    [self.completionsPopover performClose:self];
                    return;
                case ' ':
                    [self.completionsPopover performClose:self];
                    // fallthrough
                default:
                    hasTyped = TRUE;
                    [super keyDown:event];
                    return;
                }
            }
            NSInteger row = [self.table selectedRow];
            if (row >= 0) {
                id<ZKTextViewCompletion> c = self.completions[row];
                NSString *txt = isFinal ? c.finalInsertionText : c.nonFinalInsertionText;
                [self insertCompletion:txt forPartialWordRange:self.rangeForUserCompletion movement:movement isFinal:isFinal];
                if (isFinal) {
                    [self.completionsPopover performClose:self];
                    if (c.onFinalInsert != nil) {
                        hasTyped = c.onFinalInsert(self, c);
                    }
                }
            }
            return;
        }
    }
    hasTyped = TRUE;
    [super keyDown:event];
}

-(void)showPopup {
    NSRange partialWordRange = self.rangeForUserCompletion;
    self.completions = [(id<ZKTextViewDelegate>)self.delegate textView:self completionsForPartialWordRange:partialWordRange];
    if (self.completions.count > 0) {
        NSString *selected = [self.string substringWithRange:partialWordRange];
        NSInteger idx = 0;
        NSInteger selIdx = -1;
        for (id<ZKTextViewCompletion> c in self.completions) {
            if ([c.displayText caseInsensitiveCompare:selected] != NSOrderedAscending) {
                selIdx = idx;
                break;
            }
            idx++;
        }
        [self.table reloadData];
        [self scrollRowToCenterVisible:selIdx];
        if (selIdx >= 0) {
            [self.table selectRowIndexes:[NSIndexSet indexSetWithIndex:selIdx] byExtendingSelection:NO];
        } else {
            [self.table selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];
        }
        NSRange sel = [self selectedRange];
        NSRange theTextRange = [[self layoutManager] glyphRangeForCharacterRange:sel actualCharacterRange:NULL];
        NSRect layoutRect = [[self layoutManager] boundingRectForGlyphRange:theTextRange inTextContainer:[self textContainer]];
        NSPoint containerOrigin = [self textContainerOrigin];
        layoutRect.origin.x += containerOrigin.x;
        layoutRect.origin.y += containerOrigin.y;
        layoutRect.size.width +=2;
        [self.completionsPopover showRelativeToRect:layoutRect ofView:self preferredEdge:NSRectEdgeMaxY];
    }
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
    return (isblank(next) || next==',' || next=='(' || next==')' || next=='\r' || next=='\n') && !isblank(prev);
}

-(void)checkIdle {
    uint64_t now = mach_absolute_time();
    double idle = (now-lastEvent) * ticksToMilliseconds;
    if (hasTyped && (idle > 400)) {
        lastEvent = now;
        hasTyped = FALSE;
        if ([self isAtEndOfWord]) {
            [self showPopup];
        }
    }
}

// based on https://stackoverflow.com/questions/11767557/scroll-an-nstableview-so-that-a-row-is-centered
-(void)scrollRowToCenterVisible:(NSInteger)rowIdx {
    NSScrollView *sv = (NSScrollView *)self.table.superview.superview;
    NSAssert([sv isKindOfClass:[NSScrollView class]], @"failed to find scrollview that table is contained in");
    NSRect row = [self.table rectOfRow:rowIdx];
    row.origin.y -= sv.frame.size.height / 2;
    row.origin.y += row.size.height;
    row.origin.y = MAX(0,row.origin.y);
    [self.table scrollPoint:row.origin];
}

// Usually returns the partial range from the most recent beginning of a word up to the insertion point.
// May be overridden by subclassers to alter the range to be completed.  Returning (NSNotFound, 0) suppresses completion.
-(NSRange)rangeForUserCompletion {
    NSRange sel = self.selectedRange;
    NSString *txt = self.string;
    for (; sel.location > 0 ; sel.location--, sel.length++) {
        unichar c = [txt characterAtIndex:sel.location-1];
        if (isspace(c) || c ==',' || c =='.' || c =='(' || c == ')') {
            break;
        }
    }
    return sel;
}

-(IBAction)completionDoubleClicked:(id)sender {
    id<ZKTextViewCompletion> c = self.completions[[sender selectedRow]];
    [self insertCompletion:c.finalInsertionText forPartialWordRange:self.rangeForUserCompletion movement:NSTextMovementOther isFinal:YES];
    [self.completionsPopover performClose:self];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.completions.count;
}

- (NSView *)tableView:(NSTableView *)tableView
   viewForTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)row {
 
    NSTableCellView *v = [tableView makeViewWithIdentifier:@"MainCell" owner:self];
    id<ZKTextViewCompletion> c = self.completions[row];
    v.textField.stringValue = c.displayText;
    v.imageView.image = c.icon;
    return v;
}

@end
