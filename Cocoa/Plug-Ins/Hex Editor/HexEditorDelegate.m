#import "HexEditorDelegate.h"

@implementation HexEditorDelegate

/* data re-representation methods */

- (NSString *)offsetRepresentation:(NSData *)data;
{
	int row;
	int rows = ([data length] / 16) + (([data length] % 16)? 1:0);
	NSMutableString *representation = [NSMutableString string];
	
	for( row = 0; row < rows; row++ )
	{
		[representation appendFormat:@"%08lX:\n", row * 16];
	}
	
	// remove last character (the return on the end)
	[representation deleteCharactersInRange:NSMakeRange([representation length] -1, 1)];
	
	return representation;
}

- (NSString *)hexRepresentation:(NSData *)data;
{
	int row, addr, currentByte = 0, dataLength = [data length];
	int rows = (dataLength / 16) + ((dataLength % 16)? 1:0);
	char buffer[16*3], byte, hex1, hex2;
	NSMutableString *representation = [NSMutableString string];
	
	// draw bytes
	for( row = 0; row < rows; row++ )
	{
		for( addr = 0; addr < 16; addr++ )
		{
			if( currentByte < dataLength )
			{
				[data getBytes:&byte range:NSMakeRange(currentByte, 1)];
				hex1 = byte;
				hex2 = byte;
				hex1 >>= 4;
				hex1 &= 0x0F;
				hex2 &= 0x0F;
				hex1 += (hex1 < 10)? 0x30 : 0x37;
				hex2 += (hex2 < 10)? 0x30 : 0x37;
				
				buffer[addr*3]		= hex1;
				buffer[addr*3 +1]	= hex2;
				buffer[addr*3 +2]	= 0x20;
				
				// advance current byte
				currentByte++;
			}
			else
			{
				buffer[addr*3] = 0x00;
				break;
			}
		}
		
		// clear last byte on line
		buffer[16*3 -1] = 0x00;
		
		// append buffer to representation
		[representation appendString:[NSString stringWithCString:buffer]];
		if( currentByte != dataLength )
			[representation appendString:@"\n"];
	}
	
	return representation;
}

- (NSString *)asciiRepresentation:(NSData *)data;
{
	int row, addr, currentByte = 0, dataLength = [data length];
	int rows = (dataLength / 16) + ((dataLength % 16)? 1:0);
	char buffer[17], byte = 0x00;
	NSMutableString *representation = [NSMutableString string];
	
	// draw bytes
	for( row = 0; row < rows; row++ )
	{
		for( addr = 0; addr < 16; addr++ )
		{
			if( currentByte < dataLength )
			{
				[data getBytes:&byte range:NSMakeRange(currentByte, 1)];
				if( byte >= 0x20 && byte < 0x7F )
					buffer[addr] = byte;
				else buffer[addr] = 0x2E;	// full stop								
				
				// advance current byte
				currentByte++;
			}
			else
			{
				buffer[addr] = 0x00;
				break;
			}
		}
		
		// clear last byte on line
		buffer[16] = 0x00;
		
		// append buffer to representation
		[representation appendString:[NSString stringWithCString:buffer]];
		if( currentByte != dataLength )
			[representation appendString:@"\n"];
	}
	
	return representation;
}

/* delegation methods */

- (NSRange)textView:(NSTextView *)textView willChangeSelectionFromCharacterRange:(NSRange)oldSelectedCharRange toCharacterRange:(NSRange)newSelectedCharRange
{
	NSRange hexRange, asciiRange;
	
	// temporarilly removing the delegate stops this function being called recursivly!
	id oldDelegate = [hex delegate];
	[hex setDelegate:nil];
	[ascii setDelegate:nil];
	
	if( textView == hex )			// we're selecting hexadecimal
	{
		if( newSelectedCharRange.length == 0 )	// moving insertion point
		{
			asciiRange = NSMakeRange( newSelectedCharRange.location /3, 0 );
		}
		else									// dragging a selection
		{
			int numReturns = (newSelectedCharRange.length /47) + (newSelectedCharRange.location % 47? 1:0);
			asciiRange = NSMakeRange( newSelectedCharRange.location /3, (newSelectedCharRange.length+1) /3 );
		}
		NSLog( @"hex selection changed from %@ to %@", NSStringFromRange(oldSelectedCharRange), NSStringFromRange(newSelectedCharRange) );
		NSLog( @"changing ascii selection to %@", NSStringFromRange(asciiRange) );
		[ascii setSelectedRange:asciiRange];
	}
	else if( textView == ascii )	// we're selecting ASCII
	{
		
		if( newSelectedCharRange.length == 0 )	// moving insertion point
		{
			hexRange = NSMakeRange( newSelectedCharRange.location *3, 0 );
		}
		else									// dragging a selection
		{
			int numReturns = (newSelectedCharRange.length /17) + (newSelectedCharRange.location % 17? 1:0);
			hexRange = NSMakeRange( (newSelectedCharRange.location - numReturns) *3 + numReturns, ((newSelectedCharRange.length - numReturns) *3) -1 );
		}
		NSLog( @"ascii selection changed from %@ to %@", NSStringFromRange(oldSelectedCharRange), NSStringFromRange(newSelectedCharRange) );
		NSLog( @"changing hex selection to %@", NSStringFromRange(hexRange) );
		
		[hex setSelectedRange:hexRange];
	}
	
	// restore delegates
	[hex setDelegate:oldDelegate];
	[ascii setDelegate:oldDelegate];
	return newSelectedCharRange;
}
/*
- (void)textViewDidChangeSelection:(NSNotification *)notification;
{
}

- (BOOL)textView:(NSTextView *)textView shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString;
{
	if( textView == hex )				// we're editing in hexadecimal constrain to 0-9, A-F
	{
	}
	else return YES;					// we're editing in ASCII
}*/

/*
Raphael Sebbe's code
- (void)textViewDidChangeSelection:(NSNotification *)aNotification
{
    BOOL shouldUpdate = NO;
    id textView = [aNotification object];
    if(textView == _hexText)
    {
        NSRange hexRange = [textView selectedRange];
        NSRange byteRange = [HVHexInterpreter byteRangeFromHexRange:hexRange];
        
        _selectedByteRange = byteRange; shouldUpdate = YES;
    }
    else if(textView == _asciiText)
    {
        NSRange asciiRange = [textView selectedRange];
        NSRange byteRange = [HVHexInterpreter byteRangeFromAsciiRange:asciiRange];
        
        _selectedByteRange = byteRange; shouldUpdate = YES;
    }
    if(shouldUpdate) 
    {
        [self updateSelectionFeedback];
        [self updateSelectionOffsetTF];
        [self updateForms];
    }
}
*/

- (NSTextView *)hex
{
	return hex;
}

- (NSTextView *)ascii
{
	return ascii;
}

@end