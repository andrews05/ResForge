#include "Utility.h"

  /**********************/
 /* QUICKDRAW ROUTINES */
/**********************/

/*** SET COLOUR ***/
void SetColour( RGBColor *colour, UInt16 red, UInt16 green, UInt16 blue )
{
	colour->red = red;
	colour->green = green;
	colour->blue = blue;
}

/*** MAKE LOCAL ***/
void MakeLocal( WindowRef window, Point globalPoint, Point *localPoint )
{
	GrafPtr oldPort;
	GetPort( &oldPort );
	SetPortWindowPort( window );
	
	localPoint->h = globalPoint.h;
	localPoint->v = globalPoint.v;
	GlobalToLocal( localPoint );

	SetPort( oldPort );
}

/*** MAKE GLOBAL ***/
void MakeGlobal( WindowRef window, Point localPoint, Point *globalPoint )
{
	GrafPtr oldPort;
	GetPort( &oldPort );
	SetPortWindowPort( window );
	
	globalPoint->h = localPoint.h;
	globalPoint->v = localPoint.v;
	LocalToGlobal( globalPoint );

	SetPort( oldPort );
}

  /*****************************/
 /* HEX <==> ASCII CONVERSION */
/*****************************/

/*** ASCII TO TEXT ***/
void AsciiToText( char *source, char *dest, unsigned long size )
{
	char ascii = 0x00, text = 0x00;
	unsigned long sourceOffset = 0, destOffset = 0;
	while( sourceOffset < size )
	{
		ascii = *(source + sourceOffset);
		if( ascii < 0x20 || ascii >= 0x7F )	text = (char) 0x2E;	// full stop
		else if( ascii == 0x20 )			text = (char) 0xCA;	// nbsp
		else								text = ascii;
		*(dest + destOffset++) = text;
		sourceOffset++;
	}
}

/*** ASCII TO HEX ***/
void AsciiToHex( char *source, char *dest, unsigned long size )
{
	char hex1 = 0x00, hex2 = 0x00;
	unsigned long sourceOffset = 0, destOffset = 0;
	while( sourceOffset < size )
	{
		hex1 = *(source + sourceOffset);
		hex2 = *(source + sourceOffset);
		hex1 >>= 4;
		hex1 &= 0x0F;
		hex2 &= 0x0F;
		hex1 += (hex1 < 10)? 0x30 : 0x37;
		hex2 += (hex2 < 10)? 0x30 : 0x37;
		
		*(dest + destOffset++) = hex1;
		*(dest + destOffset++) = hex2;
		*(dest + destOffset++) = 0x20;
		sourceOffset++;
	}
}

/*** HEX TO ASCII ***/
void HexToAscii( char *source, char *dest, unsigned long size )
{
	char currentByte = 0x00, newByte = 0x00, tempByte = 0x00;
	unsigned long sourceOffset = 0, destOffset = 0;
	while( sourceOffset < size )
	{
		currentByte = *(source + sourceOffset);
		if( currentByte >= 0x30 && currentByte <= 0x39 )		newByte = currentByte - 0x30;	// 0 to 9
		else if( currentByte >= 0x41 && currentByte <= 0x46 )	newByte = currentByte - 0x37;	// A to F
		else if( currentByte >= 0x61 && currentByte <= 0x66 )	newByte = currentByte - 0x57;	// a to f
		else 													newByte = 0x00;
		newByte <<= 4;
		currentByte = *(source + sourceOffset +1);
		if( currentByte >= 0x30 && currentByte <= 0x39 )		tempByte = currentByte - 0x30;	// 0 to 9
		else if( currentByte >= 0x41 && currentByte <= 0x46 )	tempByte = currentByte - 0x37;	// A to F
		else if( currentByte >= 0x61 && currentByte <= 0x66 )	tempByte = currentByte - 0x57;	// a to f
		else 													tempByte = 0x00;
		newByte += tempByte & 0x0F;
		*(dest + destOffset++) = newByte;
		sourceOffset += 3;
	}
}

/*** LONG TO HEX ***/
void LongToHex( char *source, char *dest )
{
	// copy of AsciiToHex but with changes as noted
	char hex1 = 0x00, hex2 = 0x00;
	unsigned long sourceOffset = 0, destOffset = 0;
	while( sourceOffset < sizeof(unsigned long) )	// size is always four
	{
		hex1 = *(source + sourceOffset);
		hex2 = *(source + sourceOffset);
		hex1 >>= 4;
		hex1 &= 0x0F;
		hex2 &= 0x0F;
		hex1 += (hex1 < 10)? 0x30 : 0x37;
		hex2 += (hex2 < 10)? 0x30 : 0x37;
		
		*(dest + destOffset++) = hex1;
		*(dest + destOffset++) = hex2;	// no space inserted
		sourceOffset++;
	}
}

  /*******************/
 /* STRING ROUTINES */
/*******************/

/*** C STRING LENGTH ***/
unsigned long CStringLength( char *string )
{
	unsigned long length;
	Boolean end = false;
	for( length = 0; end == false; length++ )
		if( *(string + length) == 0x00 ) end = true;
	return length;
}

/*** PASCAL STRING LENGTH ***/
unsigned char PStringLength( unsigned char *string )
{
	return *string;
}

/*** TYPE TO C STRING ***/
void TypeToCString( const OSType type, char *string )
{
	BlockMoveData( &type, &string[0], sizeof(OSType) );
	string[sizeof(OSType)] = 0x00;
}

/*** TYPE TO PASCAL STRING ***/
void TypeToPString( const OSType type, Str255 string )
{
	string[0] = sizeof(OSType);
	BlockMoveData( &type, &string[1], sizeof(OSType) );
}

/*** TYPE TO CORE FOUNDATION STRING ***/
void TypeToCFString( const OSType type, CFStringRef *string )
{
	char cString[5];
	TypeToCString( type, (char *) &cString );
	*string = CFStringCreateWithCString( CFAllocatorGetDefault(), (char *) &cString, kCFStringEncodingMacRoman );
}

/*** COPY C STRING ***/
void CopyCString( UInt8 *source, UInt8 *dest )
{
//	#pragma warning off
	while( *dest++ = *source++ );
//	#pragma warning reset
}

/*** COPY PASCAL STRING ***/
void CopyPString( UInt8 *source, UInt8 *dest )
{
	UInt8 length = *source, count;
	for( count = 0; count <= length; count++ )
		*dest++ = *source++;
}

/*** EQUAL C STRINGS ***/
Boolean EqualCStrings( UInt8 *source, UInt8 *dest )
{
	while( *source != 0x00 )
		if( *source++ != *dest++ ) return false;
	return true;
}

/*** EQUAL PASCAL STRINGS ***/
Boolean EqualPStrings( UInt8 *source, UInt8 *dest )
{
	UInt8 length = *source, count;
	for( count = 0; count <= length; count++ )
		if( *source++ != *dest++ ) return false;
	return true;
}

/*** APPEND ONE PASCAL STRING ONTO ANOTHER ***/
void AppendPString( Str255 original, ConstStr255Param added )
{
	short numberBytes = added[0];		// length of string to be added
	short totalLength = added[0] + original[0];
	
	if( totalLength > 255 )				// too long, adjust number of bytes to add
	{
		totalLength = 255;
		numberBytes = totalLength - original[0];
	}
	
	BlockMoveData( &added[1], &original[totalLength-numberBytes + 1], numberBytes );
	original[0] = totalLength;			// new length of original string
	while( ++totalLength <= 255 )
		original[totalLength] = 0x00;	// set rest of string to zero
}

  /*****************/
 /* MENU ROUTINES */
/*****************/

/*** ENABLE MENU COMMAND ***/
void EnableCommand( MenuRef menu, MenuCommand command, Boolean enable )
{
	if( enable )	EnableMenuCommand( menu, command );
	else			DisableMenuCommand( menu, command );
}
