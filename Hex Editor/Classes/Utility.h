#include "Hex Editor.h"

#ifndef _ResKnife_HexEditor_Utility_
#define _ResKnife_HexEditor_Utility_

/* QuickDraw Routines */
void SetColour( RGBColor *colour, UInt16 red, UInt16 green, UInt16 blue );
void MakeLocal( WindowRef window, Point globalPoint, Point *localPoint );
void MakeGlobal( WindowRef window, Point localPoint, Point *globalPoint );

/* ASCII <=> hex */
void AsciiToText( char *source, char *dest, unsigned long size );
void AsciiToHex( char *source, char *dest, unsigned long size );
void HexToAscii( char *source, char *dest, unsigned long size );
void LongToHex( char *source, char *dest );

/* strings */
unsigned long CStringLength( char *string );
unsigned char PStringLength( unsigned char *string );
void TypeToCString( const OSType type, char *string );
void TypeToPString( const OSType type, Str255 string );
void TypeToCFString( const OSType type, CFStringRef *string );
void CopyCString( UInt8 *source, UInt8 *dest );
void CopyPString( UInt8 *source, UInt8 *dest );
Boolean EqualCStrings( UInt8 *source, UInt8 *dest );
Boolean EqualPStrings( UInt8 *source, UInt8 *dest );
void AppendPString( Str255 original, ConstStr255Param added );

void EnableCommand( MenuRef menu, MenuCommand command, Boolean enable );

#endif