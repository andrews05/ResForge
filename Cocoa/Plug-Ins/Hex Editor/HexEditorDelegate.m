#import "HexEditorDelegate.h"

/* Ideas, method names, and occasionally code stolen from HexEditor by Raphael Sebbe http://raphaelsebbe.multimania.com/ */

@implementation HexEditorDelegate

/* data re-representation methods */

- (NSString *)offsetRepresentation:(NSData *)data;
{
	int row, dataLength = [data length];
	int rows = (dataLength / 16) + ((dataLength % 16)? 1:0);
	NSMutableString *representation = [NSMutableString string];
	
	for( row = 0; row < rows; row++ )
		[representation appendFormat:@"%08lX:\n", row * 16];
	
	// remove last character (the return on the end)
	if( dataLength % 16 != 0 )
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
		if( currentByte != dataLength || dataLength % 16 == 0 )
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
		if( currentByte != dataLength || dataLength % 16 == 0 )
			[representation appendString:@"\n"];
	}
	
	return representation;
}

/* delegation methods */

- (NSRange)textView:(NSTextView *)textView willChangeSelectionFromCharacterRange:(NSRange)oldSelectedCharRange toCharacterRange:(NSRange)newSelectedCharRange
{
	NSRange hexRange, asciiRange, byteRange = NSMakeRange(0,0);
	
	// temporarilly removing the delegate stops this function being called recursivly!
	id oldDelegate = [hex delegate];
	[hex setDelegate:nil];
	[ascii setDelegate:nil];
	
	if( textView == hex )			// we're selecting hexadecimal
	{
		byteRange = [self byteRangeFromHexRange:newSelectedCharRange];
		asciiRange = [self asciiRangeFromByteRange:byteRange];
		[ascii setSelectedRange:asciiRange];
	}
	else if( textView == ascii )	// we're selecting ASCII
	{
		byteRange = [self byteRangeFromAsciiRange:newSelectedCharRange];
		hexRange = [self hexRangeFromByteRange:byteRange];
		[hex setSelectedRange:hexRange];
	}
	else NSLog( @"What the hell are you selecting?" );
	
	// put the new selection into the message bar
	[message setStringValue:[NSString stringWithFormat:@"Current selection: %@", NSStringFromRange(byteRange)]];
	
	// restore delegates
	[hex setDelegate:oldDelegate];
	[ascii setDelegate:oldDelegate];
	return newSelectedCharRange;
}

- (NSRange)byteRangeFromHexRange:(NSRange)hexRange;
{
	// valid for all window widths
	NSRange byteRange = NSMakeRange(0,0);
	
	byteRange.location = (hexRange.location / 3);
	byteRange.length = (hexRange.length / 3) + ((hexRange.length % 3)? 1:0);
	
	return byteRange;
}

- (NSRange)hexRangeFromByteRange:(NSRange)byteRange;
{
	NSRange hexRange = NSMakeRange(0,0);
	
	hexRange.location = (byteRange.location * 3);
	hexRange.length = (byteRange.length * 3);
	
	return hexRange;
}

- (NSRange)byteRangeFromAsciiRange:(NSRange)asciiRange;
{
	// assumes 16 byte wide window
	NSRange byteRange;
	
	byteRange.location = asciiRange.location - (asciiRange.location / 17);
	byteRange.length = asciiRange.length - ((asciiRange.location + asciiRange.length) / 17) +  (asciiRange.location / 17);
	
	return byteRange;
}

- (NSRange)asciiRangeFromByteRange:(NSRange)byteRange;
{
	// assumes 16 byte wide window
	NSRange asciiRange = NSMakeRange(0,0);
	
	asciiRange.location = byteRange.location + (byteRange.location / 17);
	asciiRange.length = byteRange.length + ((byteRange.location + byteRange.length) / 17) - (byteRange.location / 17);
	
	return asciiRange;
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