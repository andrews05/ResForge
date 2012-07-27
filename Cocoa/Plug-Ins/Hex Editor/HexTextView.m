#import "HexTextView.h"
#import "NSData-HexRepresentation.h"

@interface NSTextView (Private)

- (NSUInteger)_insertionGlyphIndexForDrag:(id)sender;

@end

@interface _NSUndoObject : NSObject

- (id)popUndoObject;

@end

@interface NSUndoManager (Private)

- (_NSUndoObject *)_undoStack;

@end

@implementation HexEditorTextView

/* NSText overrides */

- (IBAction)cut:(id)sender
{
	[self copy:sender];
	[self clear:sender];
}

- (IBAction)copy:(id)sender
{
	NSRange selection = [(HexEditorDelegate *)[self delegate] rangeForUserTextChange];
	NSPasteboard *pb = [NSPasteboard pasteboardWithName:NSGeneralPboard];
	
	[pb declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:self];
	[pb setData:[[(HexWindowController *)[[self window] windowController] data] subdataWithRange:selection] forType:NSStringPboardType];
}

- (IBAction)copyASCII:(id)sender
{

}

- (IBAction)copyHex:(id)sender
{

}

- (IBAction)paste:(id)sender
{
	NSRange selection = [(HexEditorDelegate *)[self delegate] rangeForUserTextChange];
	NSPasteboard *pb = [NSPasteboard pasteboardWithName:NSGeneralPboard];
	
	// pastes data as it is on the clipboard
	if([pb availableTypeFromArray:[NSArray arrayWithObject:NSStringPboardType]])
		[self editData:[[[self window] windowController] data] replaceBytesInRange:selection withData:[pb dataForType:NSStringPboardType]];
}

- (IBAction)pasteAsASCII:(id)sender
{
	NSRange selection = [(HexEditorDelegate *)[self delegate] rangeForUserTextChange];
	NSPasteboard *pb = [NSPasteboard pasteboardWithName:NSGeneralPboard];
	
	// converts whatever string encoding is on the clipboard to the default C string encoding, then pastes
	if([pb availableTypeFromArray:[NSArray arrayWithObject:NSStringPboardType]])
	{
		NSData *asciiData = [[pb stringForType:NSStringPboardType] dataUsingEncoding:[NSString defaultCStringEncoding] allowLossyConversion:YES];
		[self editData:[[[self window] windowController] data] replaceBytesInRange:selection withData:asciiData];
	}
}

- (IBAction)pasteAsUnicode:(id)sender
{
	NSRange selection = [(HexEditorDelegate *)[self delegate] rangeForUserTextChange];
	NSPasteboard *pb = [NSPasteboard pasteboardWithName:NSGeneralPboard];
	
	// converts whatever string encoding is on the clipboard to Unicode, strips off the byte order mark, then pastes
	if([pb availableTypeFromArray:[NSArray arrayWithObject:NSStringPboardType]])
	{
		NSMutableData *unicodeData = [[[pb stringForType:NSStringPboardType] dataUsingEncoding:NSUnicodeStringEncoding] mutableCopy];
		if(*((unsigned short *)[unicodeData mutableBytes]) == 0xFEFF || *((unsigned short *)[unicodeData mutableBytes]) == 0xFFFE)
			[unicodeData replaceBytesInRange:NSMakeRange(0,2) withBytes:NULL length:0];
		[self editData:[[[self window] windowController] data] replaceBytesInRange:selection withData:unicodeData];
		[unicodeData release];
	}
}

- (IBAction)pasteAsHex:(id)sender
{
	NSRange selection = [(HexEditorDelegate *)[self delegate] rangeForUserTextChange];
	NSPasteboard *pb = [NSPasteboard pasteboardWithName:NSGeneralPboard];
	
	// converts whatever data is on the clipboard to a hex representation of that data, then pastes
	if([pb availableTypeFromArray:[NSArray arrayWithObject:NSStringPboardType]])
	{
		NSData *hexData = [[[pb dataForType:NSStringPboardType] hexRepresentation] dataUsingEncoding:[NSString defaultCStringEncoding] allowLossyConversion:YES];
		[self editData:[[[self window] windowController] data] replaceBytesInRange:selection withData:hexData];
	}
}

- (IBAction)pasteFromHex:(id)sender
{
	NSRange selection = [(HexEditorDelegate *)[self delegate] rangeForUserTextChange];
	NSPasteboard *pb = [NSPasteboard pasteboardWithName:NSGeneralPboard];
	
	// converts hex data present on the clipboard to the bytes they represent, then pastes
	if([pb availableTypeFromArray:[NSArray arrayWithObject:NSStringPboardType]])
	{
		NSData *binaryData = [[pb stringForType:NSStringPboardType] dataFromHex];
		[self editData:[[[self window] windowController] data] replaceBytesInRange:selection withData:binaryData];
	}
}

- (IBAction)clear:(id)sender
{
	NSRange selection = [self rangeForUserTextChange];
	if(selection.length > 0)
		[self delete:sender];
}

- (IBAction)delete:(id)sender
{
	[self deleteBackward:sender];
}

/* Dragging routines */

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
	return NSDragOperationNone;
/*	if(isLocal) return NSDragOperationEvery;
	else return NSDragOperationCopy;
	return NSDragOperationCopy | NSDragOperationMove | NSDragOperationGeneric;
*/}

static NSRange draggedRange;

- (void)draggedImage:(NSImage *)image beganAt:(NSPoint)point
{
	draggedRange = [self rangeForUserTextChange];
}

- (void)draggedImage:(NSImage *)image endedAt:(NSPoint)point operation:(NSDragOperation)operation
{
	if(operation == NSDragOperationMove)
	{
		NSRange selection = [self rangeForUserTextChange];
		[self editData:[[[self window] windowController] data] replaceBytesInRange:draggedRange withData:[NSData data]];
		
		// set the new selection/insertion point
		selection.location -= draggedRange.length;
		selection.length = draggedRange.length;
		if(selection.location > draggedRange.location)
			selection.location -= draggedRange.length;
		[self setSelectedRange:selection];
	}
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
	[super draggingUpdated:sender];		// ignore return value
	if([sender draggingSource] == [(HexEditorDelegate *)[self delegate] hex] || [sender draggingSource] == [(HexEditorDelegate *)[self delegate] ascii])
		return NSDragOperationMove;
	else return NSDragOperationCopy;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	// get the insertion point location
	NSPasteboard *pb = [sender draggingPasteboard];
	NSData *pastedData = [pb dataForType:NSStringPboardType];
	unsigned int charIndex = (unsigned int) [self _insertionGlyphIndexForDrag:sender];
	NSRange selection;
	
	// convert hex string to data
	if([sender draggingSource] == [(HexEditorDelegate *)[self delegate] hex])
		pastedData = [[[[NSString alloc] initWithData:pastedData encoding:[NSString defaultCStringEncoding]] autorelease] dataFromHex];
	
	if([sender draggingSource] == [(HexEditorDelegate *)[self delegate] hex] || [sender draggingSource] == [(HexEditorDelegate *)[self delegate] ascii])
//	if(operation == NSDragOperationMove)
	{
		NSRange deleteRange = draggedRange;
		if(self == (id) [(HexEditorDelegate *)[self delegate] hex])
		{
			deleteRange.location /= 3;
			deleteRange.length += 1;
			deleteRange.length /= 3;
		}
		
		// if moving the data, remove the selection from the data
		[self editData:[[[self window] windowController] data] replaceBytesInRange:deleteRange withData:[NSData data]];
		
		// compensate for already removing the dragged data
		if(charIndex > draggedRange.location)
			charIndex -= draggedRange.length;
	}
	
	// insert data at insertion point
	if(self == (id) [(HexEditorDelegate *)[self delegate] hex]) charIndex /= 3;
	[self editData:[[[self window] windowController] data] replaceBytesInRange:NSMakeRange(charIndex,0) withData:pastedData];
	
	// set the new selection/insertion point
	selection = [self rangeForUserTextChange];
	selection.location -= draggedRange.length;
	selection.length = draggedRange.length;
	[self setSelectedRange:selection];
	
	return YES;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
	// override and do nothing
}

/* NSResponder overrides */

- (void)insertText:(NSString *)string
{
	NSRange selection = [(HexEditorDelegate *)[self delegate] rangeForUserTextChange];
	NSMutableData *data = [[[[[self window] windowController] data] mutableCopy] autorelease];
	NSData *replaceData = [string dataUsingEncoding:NSASCIIStringEncoding];
	
	if(self == (id) [(HexEditorDelegate *)[self delegate] hex])
	{
		// bug: iteration through each character in string is broken, paste not yet mapped to this function
		for(NSUInteger i = 0; i < [string lengthOfBytesUsingEncoding:NSASCIIStringEncoding]; i++)
		{
			unichar typedChar = [string characterAtIndex:i];
			if(typedChar >= 0x30 && typedChar <= 0x39)		typedChar -= 0x30;		// 0 to 9
			else if(typedChar >= 0x41 && typedChar <= 0x46)	typedChar -= 0x37;		// A to F
			else if(typedChar >= 0x61 && typedChar <= 0x66)	typedChar -= 0x57;		// a to f
			else return;
			
			if(![(HexEditorDelegate *)[self delegate] editedLow])	// editing low bits
			{
				// put typed char into low bits
				typedChar &= 0x0F;
				replaceData = [NSData dataWithBytes:&typedChar length:1];
				[(HexEditorDelegate *)[self delegate] setEditedLow:YES];
			}
			else								// edited low bits already
			{
				// select & retrieve old byte so it gets replaced
				char prevByte;
				selection = NSMakeRange(selection.location -1, 1);
				[data getBytes:&prevByte range:selection];
				
				// shift typed char into high bits and add new low char
				prevByte <<=  4;				// store high bit
				prevByte += typedChar & 0x0F;	// add low bit
				replaceData = [NSData dataWithBytes:&prevByte length:1];
				[(HexEditorDelegate *)[self delegate] setEditedLow:NO];
			}
		}
	}
	
	// replace bytes (updates views implicitly, records an undo)
	[self editData:data replaceBytesInRange:selection withData:replaceData];
	
	// set the new selection (insertion point)
	selection.location++;
	selection.length = 0;
	if(self == (id) [(HexEditorDelegate *)[self delegate] hex])	selection = [HexWindowController hexRangeFromByteRange:selection];
	if(self == (id) [(HexEditorDelegate *)[self delegate] ascii])  selection = [HexWindowController asciiRangeFromByteRange:selection];
	[self setSelectedRange:selection];
}

- (IBAction)deleteBackward:(id)sender
{
	NSRange selection = [(HexEditorDelegate *)[self delegate] rangeForUserTextChange];
	NSMutableData *data = [[[[self window] windowController] data] mutableCopy];
	
	// adjust selection if is insertion point
	if(selection.length == 0 && selection.location > 0)
	{
		selection.location -= 1;
		selection.length = 1;
	}
	
	// replace bytes (updates views implicitly)
	[self editData:data replaceBytesInRange:selection withData:[NSData data]];
	[data release];
	
	// set the new selection (insertion point)
	if(selection.length == 0 && selection.location > 0)
		selection.location -= 1;
	else selection.length = 0;
	if(self == (id) [(HexEditorDelegate *)[self delegate] hex])	selection = [HexWindowController hexRangeFromByteRange:selection];
	if(self == (id) [(HexEditorDelegate *)[self delegate] ascii])  selection = [HexWindowController asciiRangeFromByteRange:selection];
	[self setSelectedRange:selection];
}

- (IBAction)deleteForward:(id)sender
{
	NSRange selection = [(HexEditorDelegate *)[self delegate] rangeForUserTextChange];
	NSMutableData *data = [[[[self window] windowController] data] mutableCopy];
	
	// adjust selection if is insertion point
	if(selection.length == 0 && [self rangeForUserTextChange].location < [[self string] length] -1)
		selection.length = 1;
	
	// replace bytes (updates views implicitly)
	[self editData:data replaceBytesInRange:selection withData:[NSData data]];
	[data release];
	
	// set the new selection/insertion point
	selection = [self rangeForUserTextChange];
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

- (void)setSelectedRange:(NSRange)charRange affinity:(NSSelectionAffinity)affinity stillSelecting:(BOOL)stillSelectingFlag
{
	[super setSelectedRange:charRange affinity:affinity stillSelecting:NO];
}

- (void)editData:(NSData *)data replaceBytesInRange:(NSRange)range withData:(NSData *)newBytes
{
	// save data we're about to replace so we can restore it in an undo
	NSRange newRange = NSMakeRange(range.location, [newBytes length]);
	NSMutableData *newData = [NSMutableData dataWithData:data];
	NSData *oldBytes = [[data subdataWithRange:range] retain];	// bug: memory leak, need to release somewhere (call -[NSInvocation retainArguments] instead?)
	
	// manipulate undo stack to concatenate multiple undos
	BOOL closeUndoGroup = NO;
	id undoStack = nil;		// object of class _NSUndoStack
	if(![[[self window] undoManager] isUndoing])
		undoStack = (id) [[[self window] undoManager] _undoStack];
	
	if(undoStack && (int)[undoStack count] > 0 && [[[self window] undoManager] groupingLevel] == 0)
	{
		[undoStack popUndoObject];		// pop endUndoGrouping item
		closeUndoGroup = YES;
	}
	
	// replace bytes, save new data, updates views & selection and mark doc as edited
	[newData replaceBytesInRange:range withBytes:[newBytes bytes] length:[newBytes length]];
	[[(HexWindowController *)[[self window] windowController] resource] setData:newData];
	[self setSelectedRange:NSMakeRange(range.location + [newBytes length], 0)];
	
	// record undo with new data object
	[[[[self window] undoManager] prepareWithInvocationTarget:self] editData:newData replaceBytesInRange:newRange withData:oldBytes];
	[oldBytes release];
	[[[self window] undoManager] setActionName:NSLocalizedString(@"Typing", nil)];
	if(closeUndoGroup)
		[[[self window] undoManager] endUndoGrouping];
}

@end
	
@implementation HexTextView

/*!
@method		selectionRangeForProposedRange:granularity:
@abstract	Adjusts the selection for insertion point and byte-selection
@author		Nicholas Shanks
@created	2003-11-10
*/

- (NSRange)selectionRangeForProposedRange:(NSRange)proposedCharRange granularity:(NSSelectionGranularity)granularity
{
	NSRange newRange = proposedCharRange;
	
	if(newRange.length == 0)
	{
		// set insertion point location
		if(newRange.location % 3 == 1)	newRange.location--;
		if(newRange.location % 3 == 2)	newRange.location++;
	}
	else
	{
		// select whole bytes at a time - bug: this doesn't quite work when selecting forwards one byte with the mouse
		granularity = NSSelectByWord;
		newRange.location -= (proposedCharRange.location % 3);
		newRange.length += (proposedCharRange.location % 3);
		
		// set selection length to whole number of bytes
		if(newRange.length > 0)
		{
			if(newRange.length % 3 == 0)	newRange.length--;
			if(newRange.length % 3 == 1)	newRange.length++;
		}
	}
	
	return [super selectionRangeForProposedRange:newRange granularity:granularity];
}
//	also, lots of subclasser pasteboard support better to use than overriding copy: and paste:?  see NSTextView.h

- (void)setSelectedRange:(NSRange)newRange affinity:(NSSelectionAffinity)affinity stillSelecting:(BOOL)stillSelectingFlag
{
	if(newRange.length == 0 && stillSelectingFlag == NO)
	{
		// moving insertion point
		if(newRange.location % 3 == 1)   newRange.location += 2;
		if(newRange.location % 3 == 2)   newRange.location -= 2;
	}
	else if(stillSelectingFlag == NO && [[self window] firstResponder] == self)
	{
		NSRange oldRange = [self rangeForUserTextChange];
		
		// selecting forwards
		if(oldRange.location == newRange.location && oldRange.length != newRange.length)
//		if(affinity == NSSelectionAffinityDownstream)
		{
			// selecting first byte
			if(newRange.location % 3 == 0 && newRange.length == 1 && oldRange.length < newRange.length)
																					newRange.length += 1;
			// deselecting first byte
			if(newRange.location % 3 == 0 && newRange.length == 1 && oldRange.length > newRange.length)
																					newRange.length = 0;
			// extending selection
			else if(newRange.location % 3 == 0 && newRange.length % 3 == 0)		newRange.length += 2;
			
			// reducing selection
			else if(newRange.location % 3 == 0 && newRange.length % 3 == 1)		newRange.length -= 2;
		}
		
		// reducing forwards selection spanning multiple rows past start point
		else if(newRange.location + newRange.length == oldRange.location && newRange.length % 3 == 1 && oldRange.length > 0)
		{
			// example:		00 00 00 00 00 00 FF FF		=>		00 00 00|FF FF FF 00 00
			//				FF FF FF|00 00 00 00 00		=>		00 00 00 00 00 00 00 00
			
			newRange.location += 1;
			newRange.length -= 2;
		}
		
		// inverse of above
		else if(oldRange.location + oldRange.length == newRange.location && newRange.length % 3 == 0 && oldRange.length > 0)
		{
			// example:		00 00 00|FF FF FF 00 00		=>		00 00 00 00 00 00 FF FF
			//				00 00 00 00 00 00 00 00		=>		FF FF FF|00 00 00 00 00
			
			newRange.location += 1;
			newRange.length -= 1;
		}
		
		// reducing backwards selection spanning multiple rows past start point
		else if(oldRange.location + oldRange.length == newRange.location && newRange.length % 3 == 1 && oldRange.length > 0)
		{
			// example:		00 00 00 00 00 00|FF FF		=>		00 00 00 00 00 00 00 00
			//				FF FF FF 00 00 00 00 00		=>		00 00 00 FF FF FF|00 00
			
			newRange.location += 1;
			newRange.length -= 2;
		}
		
		// inverse of above
		else if(newRange.location + newRange.length == oldRange.location && newRange.length % 3 == 0 && oldRange.length > 0)
		{
			// example:		00 00 00 00 00 00 00 00		=>		00 00 00 00 00 00|FF FF
			//				00 00 00 FF FF FF|00 00		=>		FF FF FF 00 00 00 00 00
			
			newRange.location += 1;
			newRange.length -= 2;
		}
		
		// selecting backwards
		else if(oldRange.location != newRange.location && oldRange.length != newRange.length)
//		else if(affinity == NSSelectionAffinityDownstream)
		{
			// selecting first byte
			if(newRange.location % 3 == 2 && newRange.length == 1)			{	newRange.location -= 2;
																					newRange.length += 1;		}
			// deselecting first byte
			else if(newRange.location % 3 == 1 && newRange.length == 1)		{	newRange.location += 2;
																					newRange.length = 0;		}
			// extending selection
			else if(newRange.location % 3 == 2 && newRange.length % 3 == 0)	{	newRange.location -= 2;
																					newRange.length += 2;		}
			// reducing selection
			else if(newRange.location % 3 == 1 && newRange.length % 3 == 1)	{	newRange.location += 2;
																					newRange.length -= 2;		}
		}
	}
	
	[super setSelectedRange:newRange affinity:affinity stillSelecting:stillSelectingFlag];
}

/*!
@method		selectionRangeForProposedRange:granularity:
@abstract	Puts insertion pointer between bytes during drag operation
@author		Nicholas Shanks
@updated	2003-11-10 NGS:  Changed algorithm.
*/

- (unsigned int)_insertionGlyphIndexForDrag:(id <NSDraggingInfo>)sender
{
	unsigned int glyphIndex = (unsigned int) [super _insertionGlyphIndexForDrag:sender];
	if(glyphIndex % 3 == 1)	glyphIndex--;
	if(glyphIndex % 3 == 2)	glyphIndex++;
	return glyphIndex;
}

@end

@implementation AsciiTextView

@end
