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
	
	// select return character if selecting ascii - no longer necessary as there's a one-to-one for ascii
/*	else if( self == (id) [[self delegate] ascii] )
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
*/	
	// call the superclass to update the selection
	[super setSelectedRange:newRange affinity:affinity stillSelecting:NO];
}

/* NSResponder overrides */

- (void)insertText:(NSString *)string
{
	NSRange selection = [self rangeForUserTextChange], byteSelection;
	NSMutableData *data = [[[[self window] windowController] data] mutableCopy];
	NSData *replaceData = [NSData dataWithBytes:[string cString] length:[string cStringLength]];
	
	// get selection range
	if( self == (id) [[self delegate] hex] )
		byteSelection = [[self delegate] byteRangeFromHexRange:selection];
	else if( self == (id) [[self delegate] ascii] )
		byteSelection = [[self delegate] byteRangeFromAsciiRange:selection];
	else
	{
		NSLog( @"Inserting text into illegal object: %@", self );
		return;
	}
	
	if( self == (id) [[self delegate] hex] )
	{
		// bug: iteration through each character in string is broken, paste not yet mapped to this function
		int i;
		for( i= 0; i < [string cStringLength]; i++ )
		{
			char typedChar = [string characterAtIndex:i];
			if( typedChar >= 0x30 && typedChar <= 0x39 )		typedChar -= 0x30;		// 0 to 9
			else if( typedChar >= 0x41 && typedChar <= 0x46 )	typedChar -= 0x37;		// A to F
			else if( typedChar >= 0x61 && typedChar <= 0x66 )	typedChar -= 0x57;		// a to f
			else return;
			
			if( [[self delegate] editedLow] )	// edited low bits already
			{
				// select & retrieve old byte so it gets replaced
				char prevByte;
				byteSelection = NSMakeRange(byteSelection.location -1, 1);
				[data getBytes:&prevByte range:byteSelection];
				
				// shift typed char into high bits and add new low char
				prevByte <<=  4;				// store high bit
				prevByte += typedChar & 0x0F;	// add low bit
				replaceData = [NSData dataWithBytes:&prevByte length:1];
				[[self delegate] setEditedLow:NO];
			}
			else								// editing low bits
			{
				// put typed char into low bits
				typedChar &= 0x0F;
				replaceData = [NSData dataWithBytes:&typedChar length:1];
				[[self delegate] setEditedLow:YES];
			}
		}
	}
		
	// replace bytes (updates views implicitly)
	[data replaceBytesInRange:byteSelection withBytes:[replaceData bytes] length:[replaceData length]];
	[[(HexWindowController *)[[self window] windowController] resource] setData:data];
	
	// set the new selection/insertion point
	byteSelection.location++;
	byteSelection.length = 0;
	if( self == (id) [[self delegate] hex] )
		selection = [[self delegate] hexRangeFromByteRange:byteSelection];
	else if( self == (id) [[self delegate] ascii] )
		selection = [[self delegate] asciiRangeFromByteRange:byteSelection];
	[self setSelectedRange:selection];
	[data release];
	NSLog(@"undo manager %@", [[self window] undoManager]);
}

- (IBAction)deleteBackward:(id)sender
{
	NSRange selection = [self rangeForUserTextChange], byteSelection;
	NSMutableData *data = [[[[self window] windowController] data] mutableCopy];
	
	// get selection range
	if( self == (id) [[self delegate] hex] )
		byteSelection = [[self delegate] byteRangeFromHexRange:selection];
	else if( self == (id) [[self delegate] ascii] )
		byteSelection = [[self delegate] byteRangeFromAsciiRange:selection];
	else
	{
		NSLog( @"Inserting text into illegal object: %@", self );
		return;
	}
	
	// adjust selection if is insertion point
	if( byteSelection.length == 0 && selection.location > 0 )
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
	else if( self == (id) [[self delegate] ascii] )
		byteSelection = [[self delegate] byteRangeFromAsciiRange:selection];
	else
	{
		NSLog( @"Inserting text into illegal object: %@", self );
		return;
	}
	
	// adjust selection if is insertion point
	if( byteSelection.length == 0 && selection.location < [[self string] length] -1 )
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
