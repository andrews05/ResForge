#import "HexTextView.h"

@implementation HexTextView

- (id)init
{
	self = [super init];
	[[[NSCursor alloc] initWithImage:[NSImage imageNamed:@"Show Info"] hotSpot:NSMakePoint(0,0)] set];
	return self;
}

- (void)drawRect:(NSRect)rect
{
	[super drawRect:rect];
/*	if( [[self window] isKeyWindow] && [[self window] firstResponder] == self )
	{
		NSSetFocusRingStyle( NSFocusRingOnly );
		[self setKeyboardFocusRingNeedsDisplayInRect:rect];
	}*/
	
/*	[super drawRect:rect];
	if( [[self window] isKeyWindow] )
	{
		NSResponder *responder = [[self window] firstResponder];
		if( [responder isKindOfClass:[NSView class]] && [(NSView *)responder isDescendantOf:self])
		{
			NSSetFocusRingStyle( NSFocusRingOnly );
			NSRectFill( rect );
		}
	}
	[self setKeyboardFocusRingNeedsDisplayInRect:rect];*/
}

- (void)setSelectedRange:(NSRange)charRange affinity:(NSSelectionAffinity)affinity stillSelecting:(BOOL)flag
{
	NSRange newRange = charRange;
	
	// select whole bytes at a time (only if selecting in hex!)
	if( self == (id) [[self delegate] hex] )
	{
		// move selection offset to beginning of byte
		newRange.location -= (charRange.location % 3);
		newRange.length += (charRange.location % 3);
		
		// set selection length to whole number of bytes
		if( charRange.length != 0 )
			newRange.length -= (newRange.length % 3) -2;
		else newRange.length = 0;
		
		// move insertion point to next byte if needs be
		if( newRange.location == charRange.location -1 && newRange.length == 0 )
			newRange.location += 3;
	}
	
	// select return character if selecting ascii
	else if( self == (id) [[self delegate] ascii] )
	{
		// if ascii selection goes up to sixteenth byte on last line, select return character too
		if( (charRange.length + charRange.location) % 17 == 16)
		{
			// if selection is zero bytes long, move insertion point to character after return
			if( charRange.length == 0 )
			{
				// if moving back from first byte of line to previous line, skip return char
				NSRange selected = [self selectedRange];
				if( (selected.length + selected.location) % 17 == 0 )
					newRange.location -= 1;
				else newRange.location += 1;
			}
			else newRange.length += 1;
		}
	}
	
	// call the superclass to update the selection
	[super setSelectedRange:newRange affinity:affinity stillSelecting:NO];
}

/* NSResponder overrides */

- (IBAction)insertText:(NSString *)string
{
	NSLog( @"Inserting text: %@", string );
/*	if( hexWindow->editingHex )		// editing in hexadecimal
	{
		Boolean deletePrev = false;	// delete prev typing to add new one
		if( hexWindow->editedHigh )	// edited high bits already
		{
			// shift typed char into high bits and add new low char
			if( charCode >= 0x30 && charCode <= 0x39 )		charCode -= 0x30;		// 0 to 9
			else if( charCode >= 0x61 && charCode <= 0x66 )	charCode -= 0x57;		// a to f
			else if( charCode >= 0x93 && charCode <= 0x98 )	charCode -= 0x8A;		// A to F
			else break;
			hexWindow->hexChar <<=  4;				// store high bit
			hexWindow->hexChar += charCode & 0x0F;	// add low bit
			hexWindow->selStart += 1;
			hexWindow->selEnd = hexWindow->selStart;
			hexWindow->editedHigh = false;
			deletePrev = true;
		}
		else				// editing low bits
		{
			// put typed char into low bits
			if( charCode >= 0x30 && charCode <= 0x39 )		charCode -= 0x30;		// 0 to 9
			else if( charCode >= 0x61 && charCode <= 0x66 )	charCode -= 0x57;		// a to f
			else if( charCode >= 0x93 && charCode <= 0x98 )	charCode -= 0x8A;		// A to F
			else break;
			hexWindow->hexChar = charCode & 0x0F;
			hexWindow->editedHigh = true;
		}
		hexWindow->InsertBytes( nil, hexWindow->selStart - hexWindow->selEnd, hexWindow->selEnd );	// remove selection
		hexWindow->selEnd = hexWindow->selStart;
		if( deletePrev )
		{
			hexWindow->InsertBytes( nil, -1, hexWindow->selStart );									// remove previous hex char
			hexWindow->InsertBytes( &hexWindow->hexChar, 1, hexWindow->selStart -1 );				// insert typed char (bug fix hack)
		}
		else hexWindow->InsertBytes( &hexWindow->hexChar, 1, hexWindow->selStart );					// insert typed char
	}
	else					// editing in ascii
	{
		hexWindow->InsertBytes( nil, hexWindow->selStart - hexWindow->selEnd, hexWindow->selEnd );	// remove selection
		hexWindow->selEnd = hexWindow->selStart;
		hexWindow->InsertBytes( &charCode, 1, hexWindow->selStart );								// insert typed char
		hexWindow->selStart += 1;
		hexWindow->selEnd = hexWindow->selStart;
	}*/
}

- (IBAction)deleteBackward:(id)sender
{
	NSRange selection = [self rangeForUserTextChange], byteSelection;
	NSMutableData *data = [[[[self window] windowController] data] mutableCopy];
	
	// get selection range
	if( self == (id) [[self delegate] hex] )
		byteSelection = [[self delegate] byteRangeFromHexRange:selection];
	else byteSelection = [[self delegate] byteRangeFromAsciiRange:selection];
	
	// adjust selection if is insertion point
	if( byteSelection.length == 0 )
	{
		byteSelection.location -= 1;
		byteSelection.length = 1;
	}
	
	// replace bytes (updates views implicitly)
	[data replaceBytesInRange:byteSelection withBytes:nil length:0];
	[[(HexWindowController *)[[self window] windowController] resource] setData:data];
	[data release];
	
	// set the new selection/insertion point
	if( selection.length == 0 )
		selection.location -= 1;
	else selection.length = 0;
	[self setSelectedRange:selection];
}

- (IBAction)deleteForward:(id)sender
{
	NSRange selection = [self rangeForUserTextChange], byteSelection;
	NSMutableData *data = [[[[self window] windowController] data] mutableCopy];
	
	// get selection range
	if( self == (id) [[self delegate] hex] )
		byteSelection = [[self delegate] byteRangeFromHexRange:selection];
	else byteSelection = [[self delegate] byteRangeFromAsciiRange:selection];
	
	// adjust selection if is insertion point
	if( byteSelection.length == 0 )
		byteSelection.length = 1;
	
	// replace bytes (updates views implicitly)
	[data replaceBytesInRange:byteSelection withBytes:nil length:0];
	[[(HexWindowController *)[[self window] windowController] resource] setData:data];
	[data release];
	
	// set the new selection/insertion point
	selection.length = 0;
	[self setSelectedRange:selection];
}

- (IBAction)transpose:(id)sender
{
	;
}

- (IBAction)deleteWordBackward:(id)sender
{
	[self deleteBackward:sender];
}

- (IBAction)deleteWordForward:(id)sender
{
	[self deleteForward:sender];
}

- (IBAction)transposeWords:(id)sender
{
	[self transpose:sender];
}

@end

@implementation NSTextView (HexTextView)

- (void)swapForHexTextView
{
	isa = [HexTextView class];
}

@end
