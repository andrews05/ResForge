#include "ResKnife.h"

#ifndef _ResKnife_Files_
#define _ResKnife_Files_

/*!
	@header			File Handling Code
	@discussion		All code that reads from and writes to a file resides in here. Also contains open, save and revert dialog code.
*/

/*!
	@function		DisplayOpenDialog
	@discussion		Calls the appropriate <tt>Open()</tt> function for the system we are running on.
*/
OSStatus			DisplayOpenDialog( void );
/*!
	@function		DisplayModelessGetFileDialog
	@discussion		Requires CarbonLib 1.1 or OS X
*/
OSStatus			DisplayModelessGetFileDialog( void );
/*!
	@function		OpenFile
*/
OSStatus			OpenFile( short vRefNum, long dirID, ConstStr255Param fileName );
/*!
	@function		DisplayStandardFileOpenDialog
*/
OSStatus			DisplayStandardFileOpenDialog( void );
/*!
	@function		ModelessGetFileHandler
	@discussion		Requires CarbonLib 1.1 or OS X
*/
pascal void			ModelessGetFileHandler( const NavEventCallbackMessage callBackSelector, NavCBRecPtr cbRecord, NavCallBackUserData callBackUD );
/*!
	@function		ModelessAskSaveChangesHandler
	@discussion		Requires CarbonLib 1.1 or OS X
*/
pascal void			ModelessAskSaveChangesHandler( const NavEventCallbackMessage callBackSelector, NavCBRecPtr cbRecord, NavCallBackUserData callBackUD );
/*!
	@function		ModelessPutFileHandler
	@discussion		Requires CarbonLib 1.1 or OS X
*/
pascal void			ModelessPutFileHandler( const NavEventCallbackMessage callBackSelector, NavCBRecPtr cbRecord, NavCallBackUserData callBackUD );
/*!
	@function		ModelessAskDiscardChangesHandler
	@discussion		Requires CarbonLib 1.1 or OS X
*/
pascal void			ModelessAskDiscardChangesHandler( const NavEventCallbackMessage callBackSelector, NavCBRecPtr cbRecord, NavCallBackUserData callBackUD );
/*!
	@function		NavEventFilter
*/
pascal void			NavEventFilter( NavEventCallbackMessage callBackSelector, NavCBRecPtr cbRecord, NavCallBackUserData callBackUD );
/*!
	@function		NavPreviewFilter
*/
pascal Boolean		NavPreviewFilter( NavCBRecPtr callBackParms, void *callBackUD );
/*!
	@function		NavFileFilter
*/
pascal Boolean		NavFileFilter( AEDescPtr theItem, void *info, void *callBackUD, NavFilterModes filterMode );

#endif