#include "ResKnife.h"

#ifndef _ResKnife_Errors_
#define _ResKnife_Errors_

/*!
	@header			Errors
	@discussion		Contains all error display code for both ResKnife and it's plug-ins.
*/

/*!
	@function		DisplayError
	@discussion		Pass a CFStringRef and ResKnife will do noting at all. (yet :)
*/
OSStatus DisplayError( CFStringRef error );
/*!
	@function		DisplayError
	@discussion		Pass one pascal string and ResKnife will display a simple error message.
*/
OSStatus DisplayError( ConstStr255Param error );
/*!
	@function		DisplayError
	@discussion		Pass two string indecies within kErrorStrings, and they will be displayed as an error message.
*/
OSStatus DisplayError( UInt16 error, UInt16 explanation );
/*!
	@function		DisplayError
	@discussion		Pass two pascal strings and ResKnife will display a more refined error message.
*/
OSStatus DisplayError( ConstStr255Param error, ConstStr255Param explanation );
/*!
	@function		DebugError
	@discussion		Pass an index of a string with kDebugStrings and if debugging mode is on, ResKnife will display the message.
*/
OSStatus DebugError( UInt16 error, OSStatus number = noErr );
/*!
	@function		DebugError
	@discussion		Pass a pascal string and if debugging mode is on, ResKnife will display the message.
*/
OSStatus DebugError( ConstStr255Param errorStr, OSStatus number = noErr );

#endif