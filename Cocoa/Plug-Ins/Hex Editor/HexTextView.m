#import "HexTextView.h"

@class _NSUndoStack;

@implementation HexTextView

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
#if( 0 )	// no longer necessary as there's a one-to-one for ascii, and the thing wraps properly instead :-)
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
#endif
	
	// call the superclass to update the selection
	[super setSelectedRange:newRange affinity:affinity stillSelecting:NO];
}

/* NSText overrides */

- (BOOL)validateMenuItem:(NSMenuItem *)item
{
	// paste submenu
	if( [item action] == @selector(paste:) )
	{
		NSMenu *editMenu = [[item menu] supermenu];
		[[editMenu itemAtIndex:[editMenu indexOfItemWithSubmenu:[item menu]]] setEnabled:[super validateMenuItem:item]];
	}
	else return [super validateMenuItem:item];
}

- (IBAction)cut:(id)sender
{
	[self copy:sender];
	[self clear:sender];
}

- (IBAction)copy:(id)sender
{
	NSRange selection = [self rangeForUserTextChange], byteSelection;
	NSPasteboard *pb = [NSPasteboard pasteboardWithName:NSGeneralPboard];
	
	// get selection range
	if( self == (id) [[self delegate] hex] )
		byteSelection = [[self delegate] byteRangeFromHexRange:selection];
	else if( self == (id) [[self delegate] ascii] )
		byteSelection = [[self delegate] byteRangeFromAsciiRange:selection];
	else
	{
		NSLog( @"Pasting text into illegal object: %@", self );
		return;
	}
	
	[pb declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:self];
	[pb setData:[[[[self window] windowController] data] subdataWithRange:byteSelection] forType:NSStringPboardType];
}

- (IBAction)paste:(id)sender
{
	// be 'smart' - determine if the pasted text is in hex format, such as "5F 3E 04 8E" or ascii.
	//	what about unicode? should I paste "00 63 00 64" as "63 64" ("Paste As ASCII" submenu item)?
	
	NSRange selection = [self rangeForUserTextChange], byteSelection;
	NSPasteboard *pb = [NSPasteboard pasteboardWithName:NSGeneralPboard];
	
	// get selection range
	if( self == (id) [[self delegate] hex] )
		byteSelection = [[self delegate] byteRangeFromHexRange:selection];
	else if( self == (id) [[self delegate] ascii] )
		byteSelection = [[self delegate] byteRangeFromAsciiRange:selection];
	else
	{
		NSLog( @"Pasting text into illegal object: %@", self );
		return;
	}
	
	if( [pb availableTypeFromArray:[NSArray arrayWithObject:NSStringPboardType]] )
		[self editData:[[[self window] windowController] data] replaceBytesInRange:byteSelection withData:[pb dataForType:NSStringPboardType]];
}

- (IBAction)pasteAsASCII:(id)sender
{
	NSRange selection = [self rangeForUserTextChange], byteSelection;
	NSPasteboard *pb = [NSPasteboard pasteboardWithName:NSGeneralPboard];
	
	// get selection range
	if( self == (id) [[self delegate] hex] )
		byteSelection = [[self delegate] byteRangeFromHexRange:selection];
	else if( self == (id) [[self delegate] ascii] )
		byteSelection = [[self delegate] byteRangeFromAsciiRange:selection];
	else
	{
		NSLog( @"Pasting text into illegal object: %@", self );
		return;
	}
	
	if( [pb availableTypeFromArray:[NSArray arrayWithObject:NSStringPboardType]] )
		[self editData:[[[self window] windowController] data] replaceBytesInRange:byteSelection withData:[pb dataForType:NSStringPboardType]];
}

- (IBAction)pasteAsHex:(id)sender
{
	NSRange selection = [self rangeForUserTextChange], byteSelection;
	NSPasteboard *pb = [NSPasteboard pasteboardWithName:NSGeneralPboard];
	
	// get selection range
	if( self == (id) [[self delegate] hex] )
		byteSelection = [[self delegate] byteRangeFromHexRange:selection];
	else if( self == (id) [[self delegate] ascii] )
		byteSelection = [[self delegate] byteRangeFromAsciiRange:selection];
	else
	{
		NSLog( @"Pasting text into illegal object: %@", self );
		return;
	}
	
	if( [pb availableTypeFromArray:[NSArray arrayWithObject:NSStringPboardType]] )
	{
		NSString *hexString = [[self delegate] hexRepresentation:[pb dataForType:NSStringPboardType]];
		[self editData:[[[self window] windowController] data] replaceBytesInRange:byteSelection withData:[NSData dataWithBytes:[hexString cString] length:[hexString cStringLength]]];
	}
}

- (IBAction)pasteAsUnicode:(id)sender
{
	NSRange selection = [self rangeForUserTextChange], byteSelection;
	NSPasteboard *pb = [NSPasteboard pasteboardWithName:NSGeneralPboard];
	
	// get selection range
	if( self == (id) [[self delegate] hex] )
		byteSelection = [[self delegate] byteRangeFromHexRange:selection];
	else if( self == (id) [[self delegate] ascii] )
		byteSelection = [[self delegate] byteRangeFromAsciiRange:selection];
	else
	{
		NSLog( @"Pasting text into illegal object: %@", self );
		return;
	}
	
	if( [pb availableTypeFromArray:[NSArray arrayWithObject:NSStringPboardType]] )
	{
		NSData *unicodeData = [[NSString stringWithUTF8String:[[pb dataForType:NSStringPboardType] bytes]] dataUsingEncoding:NSUnicodeStringEncoding];
		[self editData:[[[self window] windowController] data] replaceBytesInRange:byteSelection withData:unicodeData];
	}
}

- (IBAction)clear:(id)sender
{
	NSRange selection = [self rangeForUserTextChange];
	if( selection.length > 0 )
		[self delete:sender];
}

- (IBAction)delete:(id)sender
{
	[self deleteBackward:sender];
}

/* Dragging routines */

- (unsigned int)_insertionGlyphIndexForDrag:(id <NSDraggingInfo>)sender
{
	int charIndex = [super _insertionGlyphIndexForDrag:sender];
	if( self == [[self delegate] hex] )
		charIndex -= charIndex % 3;
	return charIndex;
}

- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
	return NSDragOperationCopy | NSDragOperationMove | NSDragOperationGeneric;
}

static NSRange draggedRange;

- (void)draggedImage:(NSImage *)image beganAt:(NSPoint)point
{
	draggedRange = [self rangeForUserTextChange];
}

- (void)draggedImage:(NSImage *)image endedAt:(NSPoint)point operation:(NSDragOperation)operation
{
	if( operation == NSDragOperationMove )
	{
		NSRange selection = [self rangeForUserTextChange];
		[self editData:[[[self window] windowController] data] replaceBytesInRange:draggedRange withData:[NSData data]];
		
		// set the new selection/insertion point
		if( selection.location > draggedRange.location )
			selection.location -= draggedRange.length;
		[self setSelectedRange:selection];
	}
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
	[super draggingUpdated:sender];		// ignore return value
	if( [sender draggingSource] == [[self delegate] hex] || [sender draggingSource] == [[self delegate] ascii] )
		return NSDragOperationMove;
	else return NSDragOperationCopy;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	NSRange range;
	NSPasteboard *pb = [sender draggingPasteboard];
	NSData *pastedData = [pb dataForType:NSStringPboardType];
	int charIndex = [self _insertionGlyphIndexForDrag:sender];
	if( self == [[self delegate] hex] ) charIndex /= 3;
	if( [sender draggingSource] == [[self delegate] hex] )
		pastedData = [[[self delegate] hexToAscii:pastedData] dataUsingEncoding:NSASCIIStringEncoding];
	[self editData:[[[self window] windowController] data] replaceBytesInRange:NSMakeRange(charIndex,0) withData:pastedData];
	return YES;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
	// override and do nothing
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
		for( int i = 0; i < [string cStringLength]; i++ )
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
	
	// replace bytes (updates views implicitly, records an undo)
	[self editData:data replaceBytesInRange:byteSelection withData:replaceData];
	[data release];
	
	// set the new selection/insertion point
	byteSelection.location++;
	byteSelection.length = 0;
	if( self == (id) [[self delegate] hex] )
		selection = [[self delegate] hexRangeFromByteRange:byteSelection];
	else if( self == (id) [[self delegate] ascii] )
		selection = [[self delegate] asciiRangeFromByteRange:byteSelection];
	[self setSelectedRange:selection];
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
	[self editData:data replaceBytesInRange:byteSelection withData:[NSData data]];
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
	[self editData:data replaceBytesInRange:byteSelection withData:[NSData data]];
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

- (void)editData:(NSData *)data replaceBytesInRange:(NSRange)range withData:(NSData *)newBytes
{
	// save data we're about to replace so we can restore it in an undo
	NSRange newRange = NSMakeRange( range.location, [newBytes length] );
	NSMutableData *newData = [NSMutableData dataWithData:data];
	NSMutableData *oldBytes = [[data subdataWithRange:range] retain];	// bug: memory leak, need to release somewhere (call -[NSInvocation retainArguments] instead?)
	
	// manipulate undo stack to concatenate multiple undos
	BOOL closeUndoGroup = NO;
	_NSUndoStack *undoStack = nil;
	if( ![[[self window] undoManager] isUndoing] )
		undoStack = [[[self window] undoManager] _undoStack];
	
	if( undoStack && [undoStack count] > 0 && [[[self window] undoManager] groupingLevel] == 0 )
	{
		[undoStack popUndoObject];		// pop endUndoGrouping item
		closeUndoGroup = YES;
	}
	
	// replace bytes, save new data, updates views & selection and mark doc as edited
	[newData replaceBytesInRange:range withBytes:[newBytes bytes] length:[newBytes length]];
	[[(HexWindowController *)[[self window] windowController] resource] setData:newData];
	[self setSelectedRange:NSMakeRange(range.location + [newBytes length], 0)];
	[[self window] setDocumentEdited:YES];
	
	// record undo with new data object
	[[[[self window] undoManager] prepareWithInvocationTarget:self] editData:newData replaceBytesInRange:newRange withData:oldBytes];
	[[[self window] undoManager] setActionName:NSLocalizedString(@"Typing", nil)];
	if( closeUndoGroup )
		[[[self window] undoManager] endUndoGrouping];
//	NSLog( @"%@", undoStack );
}

@end

@implementation NSTextView (HexTextView)

- (void)swapForHexTextView
{
	isa = [HexTextView class];
}

@end