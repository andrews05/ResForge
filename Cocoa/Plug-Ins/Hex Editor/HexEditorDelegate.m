#import "HexEditorDelegate.h"
#import "HexWindowController.h"

/* Ideas, method names, and occasionally code stolen from HexEditor by Raphael Sebbe http://raphaelsebbe.multimania.com/ */

@implementation HexEditorDelegate

/* data re-representation methods */

- (NSString *)offsetRepresentation:(NSData *)data;
{
	int row, dataLength = [data length], bytesPerRow = [controller bytesPerRow];
	int rows = (dataLength / bytesPerRow) + ((dataLength % bytesPerRow)? 1:0);
	NSMutableString *representation = [NSMutableString string];
	
	for( row = 0; row < rows; row++ )
		[representation appendFormat:@"%08lX:", row * bytesPerRow];
	
	return representation;
}

- (NSString *)hexRepresentation:(NSData *)data;
{
	int row, addr, currentByte = 0, dataLength = [data length], bytesPerRow = [controller bytesPerRow];
	int rows = (dataLength / bytesPerRow) + ((dataLength % bytesPerRow)? 1:0);
	char buffer[bytesPerRow*3 +1], hex1, hex2;
	char *bytes = (char *) [data bytes];
	NSMutableString *representation = [NSMutableString string];
	
	// calculate bytes
	for( row = 0; row < rows; row++ )
	{
		for( addr = 0; addr < bytesPerRow; addr++ )
		{
			if( currentByte < dataLength )
			{
				hex1 = bytes[currentByte];
				hex2 = bytes[currentByte];
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
		buffer[bytesPerRow*3] = 0x00;
		
		// append buffer to representation
		[representation appendString:[NSString stringWithCString:buffer]];
	}
	
	return representation;
}

- (NSString *)asciiRepresentation:(NSData *)data;
{
	int row, addr, currentByte = 0, dataLength = [data length], bytesPerRow = [controller bytesPerRow];
	int rows = (dataLength / bytesPerRow) + ((dataLength % bytesPerRow)? 1:0);
	char buffer[bytesPerRow +1];
	char *bytes = (char *) [data bytes];
	NSMutableString *representation = [NSMutableString string];
	
	// calculate bytes
	for( row = 0; row < rows; row++ )
	{
		for( addr = 0; addr < bytesPerRow; addr++ )
		{
			if( currentByte < dataLength )
			{
				if( bytes[currentByte] > 0x20 && bytes[currentByte] < 0x7F )
					buffer[addr] = bytes[currentByte];
				else if( bytes[currentByte] == 0x20 )
					buffer[addr] = 0xCA;	// nbsp to stop maligned wraps
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
		buffer[bytesPerRow] = 0x00;
		
		// append buffer to representation
		[representation appendString:[NSString stringWithCString:buffer]];
	}
	
	return representation;
}

/* delegation methods */

// I'm going to try a lower level approach overriding NSResponder methods in the HexTextView class.

/*- (BOOL)textView:(NSTextView *)textView shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString;
{
#warning Every time a character is typed or string pasted, the entire resource is duplicated, operated on and disposed of! Perhaps I could do this in a better way?
	NSMutableData *data = [NSMutableData dataWithData:[controller data]];
	NSMutableData *newData = [NSMutableData dataWithBytes:[replacementString cString] length:[replacementString cStringLength]];
	NSRange range;
	
	NSLog( @"Delegate received:\ntextView: shouldChangeTextInRange:%@ replacementString:%@", NSStringFromRange(affectedCharRange), replacementString );
	
	if( textView == hex )			range = [self byteRangeFromHexRange:affectedCharRange];
	else if( textView == ascii )	range = [self byteRangeFromAsciiRange:affectedCharRange];
	else return YES;

#warning Does not cater for delete, forward delete, etc.
	[data replaceBytesInRange:range withBytes:[newData bytes] length:[newData length]];
	
	// update resource data - this causes a notification to be sent out, which the plug receives and acts upon to update the text views
	[[controller resource] setData:data];
	return NO;
}*/

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
		if( hexRange.length > 0 )
			hexRange.length -= 1;
		[hex setSelectedRange:hexRange];
	}
	
	// put the new selection into the message bar
	[message setStringValue:[NSString stringWithFormat:@"Current selection: %@", NSStringFromRange(byteRange)]];
	
	// restore delegates
	[hex setDelegate:oldDelegate];
	[ascii setDelegate:oldDelegate];
	return newSelectedCharRange;
}

/* range conversion methods */

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
	// valid for all window widths
	NSRange hexRange = NSMakeRange(0,0);
	hexRange.location = (byteRange.location * 3);
	hexRange.length = (byteRange.length * 3);
	return hexRange;
}

- (NSRange)byteRangeFromAsciiRange:(NSRange)asciiRange;
{
	// one-to-one mapping
	return asciiRange;
}

- (NSRange)asciiRangeFromByteRange:(NSRange)byteRange;
{
	// one-to-one mapping
	return byteRange;
}

- (NSTextView *)hex
{
	return hex;
}

- (NSTextView *)ascii
{
	return ascii;
}

@end