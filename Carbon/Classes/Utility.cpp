#include "Utility.h"
extern globals g;

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

/* investigate the call ShieldCursor() - it hides the mouse when it enters a certain rect */

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
void CopyCString( const UInt8 *source, UInt8 *dest )
{
//#pragma warning off
	while( *dest++ = *source++ );
//#pragma warning reset
}

/*** COPY PASCAL STRING ***/
void CopyPString( const UInt8 *source, UInt8 *dest )
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

/*** MENU ITEM ENABLE ***/
void MenuItemEnable( MenuRef menu, MenuItemIndex item, Boolean enable )
{
#if !TARGET_API_MAC_CARBON
	if( g.systemVersion >= kMacOS85 )
	{
#endif
		if( enable )	EnableMenuItem( menu, item );
		else			DisableMenuItem( menu, item );
#if !TARGET_API_MAC_CARBON
	}
	else
	{
		if( enable )	EnableItem( menu, item );
		else			DisableItem( menu, item );
	}
#endif
}

/*** ENABLE MENU COMMAND ***/
void EnableCommand( MenuRef menu, MenuCommand command, Boolean enable )
{
	if( enable )	EnableMenuCommand( menu, command );
	else			DisableMenuCommand( menu, command );
}

  /******************/
 /* FILE UTILITIES */
/******************/

/* MakeRelativeAliasFile creates a new alias file located at
    aliasDest referring to the targetFile.  relative path
    information is stored in the new file. */

/* MAKE RELATIVE ALIAS FILE */
OSErr MakeRelativeAliasFile(FSSpec *targetFile, FSSpec *aliasDest)
{
	OSErr error;
	FInfo fndrInfo;
	AliasHandle theAlias = null;
	Boolean fileCreated = false;
	SInt16 rsrc = -1;

	// set up our the alias' file information
	error = FSpGetFInfo( targetFile, &fndrInfo );
	if( error != noErr ) goto bail;
	if( fndrInfo.fdType == 'APPL')
		fndrInfo.fdType = kApplicationAliasType;
	fndrInfo.fdFlags = kIsAlias;	// implicitly clear the inited bit
	
	// create the new file
	FSpCreateResFile( aliasDest, 'TEMP', 'TEMP', smSystemScript );
	if( (error = ResError() ) != noErr) goto bail;
	fileCreated = true;
	
	// set the file information or the new file
	error = FSpSetFInfo( aliasDest, &fndrInfo );
	if( error != noErr ) goto bail;
	
	// create the alias record, relative to the new alias file
	error = NewAlias( aliasDest, targetFile, &theAlias );
	if( error != noErr ) goto bail;
	
	// save the resource
	rsrc = FSpOpenResFile( aliasDest, fsRdWrPerm );
	if( rsrc == -1)
	{
		error = ResError();
		goto bail;
	}
	UseResFile( rsrc );
	AddResource( (Handle) theAlias, rAliasType, 0, aliasDest->name );
	error = ResError();
	if( error != noErr) goto bail;
	theAlias = null;
	CloseResFile( rsrc );
	rsrc = -1;
	error = ResError();
	if( error != noErr) goto bail;
	
	// done
	return noErr;
bail:
    if( rsrc != -1 )		CloseResFile( rsrc );
    if( fileCreated )		FSpDelete( aliasDest );
    if( theAlias != null )	DisposeHandle( (Handle) theAlias );
    return error;
}

  /**********************/
 /* INTERNET UTILITIES */
/**********************/

/*** LAUNCH WEB BROWSER ***/
OSStatus LaunchURL( char *url )
{
	OSStatus error = noErr;
	ICInstance instance;
	error = ICStart( &instance, kResKnifeCreator );
	if( error != noErr ) return error;
	
	SInt32 start = 0, length = CStringLength( url );
	error = ICLaunchURL( instance, null, url, length, &start, &length );
	ICStop( instance );
	return error;
}