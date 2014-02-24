#import "NSData-HexRepresentation.h"

@implementation NSData (ResKnifeHexRepresentationExtensions)

- (NSString *)hexRepresentation
{
	NSInteger currentByte = 0, dataLength = [self length];
	char buffer[dataLength*3 -1], hex1, hex2;
	char *bytes = (char *) [self bytes];
	
	// return empty string if no data
	if(dataLength == 0) return [NSString string];
	
	// calculate bytes
	for(currentByte = 0; currentByte < dataLength; currentByte++)
	{
		hex1 = bytes[currentByte];
		hex2 = bytes[currentByte];
		hex1 >>= 4;
		hex1 &= 0x0F;
		hex2 &= 0x0F;
		hex1 += (hex1 < 10)? 0x30 : 0x37;
		hex2 += (hex2 < 10)? 0x30 : 0x37;
		
		buffer[currentByte*3]    = hex1;
		buffer[currentByte*3 +1] = hex2;
		buffer[currentByte*3 +2] = 0x20;
	}
	
	return [[[NSString alloc] initWithBytes:buffer length:(dataLength*3 -1) encoding:NSASCIIStringEncoding] autorelease];
}

- (NSString *)asciiRepresentation
{
	NSInteger currentByte = 0, dataLength = [self length];
	char buffer[dataLength];
	char *bytes = (char *) [self bytes];
	
	// calculate bytes
	for(currentByte = 0; currentByte < dataLength; currentByte++)
	{
		if(bytes[currentByte] >= 0x20 && bytes[currentByte] < 0x7F)
			buffer[currentByte] = bytes[currentByte];
		else buffer[currentByte] = 0x2E;	// full stop								
	}
	
	return [[[NSString alloc] initWithBytes:buffer length:dataLength encoding:NSASCIIStringEncoding] autorelease];
}

- (NSString *)nonLossyAsciiRepresentation
{
	NSInteger currentByte = 0, dataLength = [self length];
	char buffer[dataLength];
	char *bytes = (char *) [self bytes];
	
	// calculate bytes
	for(currentByte = 0; currentByte < dataLength; currentByte++)
	{
		if(bytes[currentByte] > 0x20)		// doesn't check for < 0x7F
			buffer[currentByte] = bytes[currentByte];
		//else if(bytes[currentByte] == 0x20)
		//	buffer[currentByte] = 0xCA;	// nbsp to stop maligned wraps - doesn't work :(
		else buffer[currentByte] = 0x2E;	// full stop								
	}
	
	return [[[NSString alloc] initWithBytes:buffer length:dataLength encoding:NSASCIIStringEncoding] autorelease];
}

@end

@implementation NSString (ResKnifeHexConversionExtensions)

- (NSData *)dataFromHex
{
	unsigned long actualBytesEncoded = 0;
	unsigned long maxBytesEncoded = (unsigned long)floor([self lengthOfBytesUsingEncoding:NSASCIIStringEncoding] / 2.0);
	const char *bytes = [self cStringUsingEncoding:NSASCIIStringEncoding];
	char *buffer = (char *) malloc(maxBytesEncoded);
	signed char hex1, hex2;
	unsigned long i;
	
	for(i = 0; i < maxBytesEncoded * 2;)
	{
		hex1 = bytes[i];
		hex2 = bytes[i+1];
		hex1 -= (hex1 < 'A')? 0x30 : ((hex1 < 'a')? 0x37 : 0x57);   // 0-9 < A-Z < a-z
		hex2 -= (hex2 < 'A')? 0x30 : ((hex2 < 'a')? 0x37 : 0x57);
		if(hex1 & 0xF0 || hex2 & 0xF0) { i++; continue; }			// invalid character found, move forward one byte and try again
		buffer[actualBytesEncoded++] = (char)(hex1 << 4) + hex2;
		i += 2;
	}
	return [NSData dataWithBytesNoCopy:buffer length:actualBytesEncoded freeWhenDone:YES];
}

@end
