#include "Errors.h"
#include "Application.h"
#include "Utility.h"

// import globals and prefs from Application.cpp
extern globals g;
extern prefs p;

/*** DISPLAY ANY ERROR ***/
OSStatus DisplayError( CFStringRef errorStr )
{
	#pragma unused( errorStr )
	return noErr;
}

/*** DISPLAY SIMPLE ERROR ***/
OSStatus DisplayError( ConstStr255Param errorStr )
{
	return DisplayError( errorStr, "\p" );
}

/*** DISPLAY ERROR WITH EXPLANATION */
OSStatus DisplayError( UInt16 error, UInt16 explanation )
{
	Str255 errorStr, explanationStr;
	GetIndString( errorStr, kErrorStrings, error );
	GetIndString( explanationStr, kErrorStrings, explanation );
	return DisplayError( errorStr, explanationStr );
}

/*** DISPLAY ERROR WITH EXPLANATION */
OSStatus DisplayError( ConstStr255Param errorStr, ConstStr255Param explanationStr )
{
	if( g.surpressErrors ) return noErr;
	if( g.useAppearance )
	{
		SInt16 item;
		AlertStdAlertParamRec params = {};
		params.movable			= true;
		params.defaultButton	= kAlertStdAlertOKButton;
		params.position			= kWindowDefaultPosition;
		
#if __profile__
		ProfilerSetStatus( false );
#endif
		SysBeep(0);
		StandardAlert( kAlertStopAlert, errorStr, explanationStr, &params, &item );
#if __profile__
		ProfilerSetStatus( true );
#endif
		return item == kAlertStdAlertOKButton? noErr:paramErr;
	}
	else
	{
		ParamText( errorStr, explanationStr, "\p", "\p" );
		ModalFilterUPP filter = null;	// NewModalFilterUPP( ParseDialogEvents );
#if __profile__
		ProfilerSetStatus( false );
#endif
		SysBeep(0);
		DialogItemIndex item = StopAlert( 128, filter );
#if __profile__
		ProfilerSetStatus( true );
#endif
		return item == kAlertStdAlertOKButton? noErr:paramErr;
	}
}

/*** DISPLAY ERROR WITH EXPLANATION */
OSStatus DebugError( UInt16 error, OSStatus number )
{
	Str255 errorStr;
	GetIndString( errorStr, kDebugStrings, error );
	return DebugError( errorStr, number );
}

/*** DISPLAY A DEBUGGING ERROR ***/
OSStatus DebugError( ConstStr255Param errorStr, OSStatus number )
{
	OSStatus error = noErr;
	if( g.debug )
	{
		Str255 message = "\pDebugging Error ID: ", numString = "\p";
		NumToString( number, numString );
		AppendPString( message, numString );
		error = DisplayError( message, errorStr );
	}
	return error;
}