#include "PickerWindow.h"
#include "FileWindow.h"
#include "Errors.h"
#include "Utility.h"

extern globals g;

/*** CREATOR ***/
PickerWindow::PickerWindow( FileWindowPtr ownerFile, ResType resType ) : PlugWindow( ownerFile )
{
	OSStatus error = noErr;
	
#if USE_NIBS
	// create a nib reference (only searches the application bundle)
	IBNibRef nibRef = null;
	error = CreateNibReference( CFSTR("ResKnife"), &nibRef );
	if( error != noErr || nibRef == null )
	{
		DisplayError( "\pThe nib file reference could not be obtained." );
		return;
	}
	
	// create window
	error = CreateWindowFromNib( nibRef, CFSTR("Picker Window"), &window );
	if( error != noErr || window == null )
	{
		DisplayError( "\pA picker window could not be obtained from the nib file." );
		return;
	}
	
	// dispose of nib ref
	DisposeNibReference( nibRef );
	
#elif TARGET_API_MAC_CARBON
	// create window
	Rect creationBounds;
	SetRect( &creationBounds, 9, 45, 256 +9, 256 +45 );
	error = CreateNewWindow( kDocumentWindowClass, kWindowStandardDocumentAttributes | kWindowStandardHandlerAttribute, &creationBounds, &window );
#else
	if( g.useAppearance && g.systemVersion >= kMacOS8 )
	{
		window = GetNewCWindow( kFileWindow8, null, kFirstWindowOfClass );
		themeSavvy = true;
	}
	else
	{
		window = GetNewCWindow( kFileWindow7, null, kFirstWindowOfClass );
		themeSavvy = false;
	}
#endif
	
	// set up default window title
	Str255 windowTitle, resTypeStr;
	FSSpec spec = *ownerFile->GetFileSpec();
	CopyPString( spec.name, windowTitle );
	TypeToPString( resType, resTypeStr );
	AppendPString( windowTitle, "\p: " );
	AppendPString( windowTitle, resTypeStr );
	AppendPString( windowTitle, "\p resources" );
	
	// save PickerWindow class in window's refcon
	SetWindowRefCon( window, (UInt32) this );
	SetWindowKind( window, kPickerWindowKind );
	SetWindowTitle( window, windowTitle );
	
	// set window's background to default for theme
#if TARGET_API_MAC_CARBON
	SetThemeWindowBackground( window, kThemeBrushDocumentWindowBackground, true );
#else
	if( g.useAppearance )
		SetThemeWindowBackground( window, kThemeBrushDocumentWindowBackground, false );
#endif
}