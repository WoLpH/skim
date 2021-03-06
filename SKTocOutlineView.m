//
//  SKTocOutlineView.m
//  Skim
//
//  Created by Christiaan Hofman on 2/25/07.
/*
 This software is Copyright (c) 2007-2015
 Christiaan Hofman. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Christiaan Hofman nor the names of any
    contributors may be used to endorse or promote products derived
    from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SKTocOutlineView.h"
#import "SKTypeSelectHelper.h"
#import "NSColor_SKExtensions.h"
#import "SKImageToolTipWindow.h"
#import "NSEvent_SKExtensions.h"

#define MAX_HIGHLIGHTS 5

@implementation SKTocOutlineView

@dynamic hasImageToolTips;

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    SKDESTROY(trackingAreas);
    [super dealloc];
}

- (void)drawRow:(NSInteger)row clipRect:(NSRect)clipRect {
    if ([[self delegate] respondsToSelector:@selector(outlineView:highlightLevelForRow:)] &&
        [self isRowSelected:row] == NO) {
        
        NSUInteger level = [[self delegate] outlineView:self highlightLevelForRow:row];
        
        if (level < MAX_HIGHLIGHTS) {
            
            NSColor *color = nil;
            NSWindow *window = [self window];
            if ([window isKeyWindow] && [window firstResponder] == self)
                color = [NSColor keySourceListHighlightColor];
            else if ([window isMainWindow] || [window isKeyWindow])
                color = [NSColor mainSourceListHighlightColor];
            else
                color = [NSColor disabledSourceListHighlightColor];
            
            if (color) {
                NSRect rect = [self rectOfRow:row];
                if (NSIntersectsRect(rect, clipRect)) {
                    [NSGraphicsContext saveGraphicsState];
                    [[color colorWithAlphaComponent:0.1 * (MAX_HIGHLIGHTS - level)] setFill];
                    [NSBezierPath fillRect:rect];
                    [NSGraphicsContext restoreGraphicsState];
                }
            }
        }
    }
    
    [super drawRow:row clipRect:clipRect];
}

- (void)highlightSelectionInClipRect:(NSRect)clipRect {
    if ([self selectionHighlightStyle] == NSTableViewSelectionHighlightStyleRegular) {
        [NSGraphicsContext saveGraphicsState];
        NSColor *color = nil;
        if ([[self window] isKeyWindow] && [[self window] firstResponder] == self)
            color = [NSColor keySourceListHighlightColor];
        else if ([[self window] isMainWindow] || [[self window] isKeyWindow])
            color = [NSColor mainSourceListHighlightColor];
        else
            color = [NSColor disabledSourceListHighlightColor];
        [color setFill];
        [[self selectedRowIndexes] enumerateIndexesUsingBlock:^(NSUInteger row, BOOL *stop){
                NSRectFill([self rectOfRow:row]);
            }];
        [NSGraphicsContext restoreGraphicsState];
    } else {
        [super highlightSelectionInClipRect:clipRect];
    }
}

- (void)handleHighlightsChanged {
    if ([[self delegate] respondsToSelector:@selector(outlineView:highlightLevelForRow:)])
        [self setNeedsDisplay:YES];
}

- (void)selectRowIndexes:(NSIndexSet *)indexes byExtendingSelection:(BOOL)extendSelection {
    [super selectRowIndexes:indexes byExtendingSelection:extendSelection];
    [self handleHighlightsChanged];
}

- (void)deselectRow:(NSInteger)row {
    [super deselectRow:row];
    [self handleHighlightsChanged];
}

- (BOOL)becomeFirstResponder {
    if ([super becomeFirstResponder]) {
        [self handleHighlightsChanged];
        return YES;
    }
    return NO;
}

- (BOOL)resignFirstResponder {
    if ([super resignFirstResponder]) {
        [self handleHighlightsChanged];
        return YES;
    }
    return NO;
}

- (void)handleKeyOrMainStateChanged:(NSNotification *)note {
    if ([self selectionHighlightStyle] == NSTableViewSelectionHighlightStyleSourceList) {
        [self handleHighlightsChanged];
    } else {
        if ([[self window] isMainWindow] || [[self window] isKeyWindow])
            [self setBackgroundColor:[NSColor mainSourceListBackgroundColor]];
        else
            [self setBackgroundColor:[NSColor controlBackgroundColor]];
        [self setNeedsDisplay:YES];
    }
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow {
    NSWindow *oldWindow = [self window];
    NSArray *names = [NSArray arrayWithObjects:NSWindowDidBecomeMainNotification, NSWindowDidResignMainNotification, NSWindowDidBecomeKeyNotification, NSWindowDidResignKeyNotification, nil];
    if (oldWindow) {
        for (NSString *name in names)
            [[NSNotificationCenter defaultCenter] removeObserver:self name:name object:oldWindow];
    }
    if (newWindow) {
        for (NSString *name in names)
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleKeyOrMainStateChanged:) name:name object:newWindow];
    }
    [super viewWillMoveToWindow:newWindow];
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    if ([self window])
        [self handleKeyOrMainStateChanged:nil];
}

- (void)removeTrackingAreas {
    if (trackingAreas == nil)
        return;
    
    for (NSTrackingArea *area in trackingAreas)
        [self removeTrackingArea:area];
    [trackingAreas removeAllObjects];
}

- (void)addTrackingAreaForRow:(NSInteger)row {
    if (trackingAreas == nil)
        return;
    
    NSDictionary *userInfo = [[NSDictionary alloc] initWithObjectsAndKeys:[NSNumber numberWithInteger:row], @"row", nil];
    NSTrackingArea *area = [[NSTrackingArea alloc] initWithRect:[self rectOfRow:row] options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInActiveApp owner:self userInfo:userInfo];
    [self addTrackingArea:area];
    [trackingAreas addObject:area];
    [area release];
    [userInfo release];
}

- (void)rebuildTrackingAreas {
    if (trackingAreas == nil || [[self delegate] respondsToSelector:@selector(outlineView:imageContextForItem:)] == NO)
        return;
    
    [self removeTrackingAreas];
    
    if ([self window]) {
        NSRect visibleRect = [self visibleRect];
        NSRange rowRange = [self rowsInRect:visibleRect];
        NSUInteger row;
        
        for (row = rowRange.location; row < NSMaxRange(rowRange); row++)
            [self addTrackingAreaForRow:row];
    }
}

- (void)reloadData {
    [super reloadData];
	[self rebuildTrackingAreas];
}

- (void)updateTrackingAreas {
	[super updateTrackingAreas];
    [self rebuildTrackingAreas];
}

- (void)noteNumberOfRowsChanged {
	[super noteNumberOfRowsChanged];
	[self rebuildTrackingAreas];
}

- (BOOL)hasImageToolTips {
    return trackingAreas != nil;
}

- (void)setHasImageToolTips:(BOOL)flag {
    if (flag && trackingAreas == nil) {
        trackingAreas = [[NSMutableSet alloc] init];
        if ([self window])
            [self rebuildTrackingAreas];
    } else if (flag == NO && trackingAreas) {
        if ([self window])
            [self removeTrackingAreas];
        SKDESTROY(trackingAreas);
    }
}

- (void)mouseEntered:(NSEvent *)theEvent{
    if (trackingAreas == nil)
        return;
    
    NSDictionary *userInfo = [theEvent userData];
    NSNumber *rowNumber = [userInfo objectForKey:@"row"];
    if (rowNumber) {
        id item = [self itemAtRow:[rowNumber integerValue]];
        id <SKImageToolTipContext> context = [[self delegate] outlineView:self imageContextForItem:item];
        if (context)
            [[SKImageToolTipWindow sharedToolTipWindow] showForImageContext:context atPoint:NSZeroPoint];
    }
}

- (void)mouseExited:(NSEvent *)theEvent{
    NSDictionary *userInfo = [theEvent userData];
    if ([userInfo objectForKey:@"row"])
        [[SKImageToolTipWindow sharedToolTipWindow] fadeOut];
}

- (void)keyDown:(NSEvent *)theEvent {
    unichar eventChar = [theEvent firstCharacter];
	NSUInteger modifiers = [theEvent standardModifierFlags];
    
    if (eventChar == NSLeftArrowFunctionKey && modifiers == (NSCommandKeyMask | NSAlternateKeyMask))
        [self collapseItem:nil collapseChildren:YES];
    else if (eventChar == NSRightArrowFunctionKey && modifiers == (NSCommandKeyMask | NSAlternateKeyMask))
        [self expandItem:nil expandChildren:YES];
    else
        [super keyDown:theEvent];
}

- (id <SKTocOutlineViewDelegate>)delegate {
    return (id <SKTocOutlineViewDelegate>)[super delegate];
}

- (void)setDelegate:(id <SKTocOutlineViewDelegate>)newDelegate {
    [super setDelegate:newDelegate];
	[self rebuildTrackingAreas];
}

@end
