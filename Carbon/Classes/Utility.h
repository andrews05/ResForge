#include "ResKnife.h"

#ifndef _ResKnife_Utility_
#define _ResKnife_Utility_

/*!
	@header			Utility Routines
	@discussion		Supplies the application with generic oft-used functions such as string conversion and menu enabling.
*/

/*!
	@function		SetColour
*/
void SetColour( RGBColor *colour, UInt16 red, UInt16 green, UInt16 blue );
/*!
	@function		CStringLength
*/
unsigned long CStringLength( char *string );
/*!
	@function		PStringLength
*/
unsigned char PStringLength( unsigned char *string );
/*!
	@function		TypeToCString
*/
void TypeToCString( const OSType type, char *string );
/*!
	@function		TypeToPString
*/
void TypeToPString( const OSType type, Str255 string );
/*!
	@function		TypeToCFString
*/
void TypeToCFString( const OSType type, CFStringRef *string );
/*!
	@function		CopyCString
*/
void CopyCString( const UInt8 *source, UInt8 *dest );
/*!
	@function		CopyPString
*/
void CopyPString( const UInt8 *source, UInt8 *dest );
/*!
	@function		EqualCStrings
*/
Boolean EqualCStrings( UInt8 *source, UInt8 *dest );
/*!
	@function		EqualPStrings
*/
Boolean EqualPStrings( UInt8 *source, UInt8 *dest );
/*!
	@function		AppendPString
*/
void AppendPString( Str255 original, ConstStr255Param added );
/*!
	@function		MenuItemEnable
*/
void MenuItemEnable( MenuRef menu, MenuItemIndex item, Boolean enable );
/*!
	@function		EnableCommand
*/
void EnableCommand( MenuRef menu, MenuCommand command, Boolean enable );
/*!
	@function		MakeRelativeAliasFile
*/
OSErr MakeRelativeAliasFile(FSSpec *targetFile, FSSpec *aliasDest);
/*!
	@function		LaunchURL
	@param url		A C string containing the address to which you want the user to go. You must include 'http://' if necessary, and all addresses to a directory should have a trailing slash.
*/
OSStatus LaunchURL( char *url );

#endif