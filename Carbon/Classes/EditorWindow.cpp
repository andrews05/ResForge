#include "EditorWindow.h"
#include "ResourceObject.h"
#include "Errors.h"
#include "Utility.h"

extern globals g;

/*** CREATOR ***/
EditorWindow::EditorWindow( FileWindowPtr ownerFile, ResourceObjectPtr targetResource, WindowRef inputWindow ) : PlugWindow( ownerFile )
{
//	OSStatus error = noErr;

	// set default variables
	window = inputWindow;
	resource = targetResource;
	
	// set up default window title
	Str255 windowTitle, resTypeStr, resIDStr;
	FSSpec spec = *ownerFile->GetFileSpec();
	CopyPString( spec.name, windowTitle );
	TypeToPString( resource->Type(), resTypeStr );
	NumToString( resource->ID(), resIDStr );
	AppendPString( windowTitle, "\p: " );
	AppendPString( windowTitle, resTypeStr );
	AppendPString( windowTitle, "\p " );
	AppendPString( windowTitle, resIDStr );
	if( *resource->Name() != 0x00 )	// resource has name
	{
		AppendPString( windowTitle, "\p, “" );
		AppendPString( windowTitle, resource->Name() );
		AppendPString( windowTitle, "\p”" );
	}
	
	// save EditorWindow class in window's refcon
	SetWindowRefCon( window, (UInt32) this );
	SetWindowKind( window, kEditorWindowKind );
	SetWindowTitle( window, windowTitle );
}

#if !TARGET_API_MAC_CARBON

/*** CLOSE ***/
OSStatus EditorWindow::Close( void )
{
	// bug: need to tell plug it is about to die.
	CloseWindow( window );
	delete this;
	return noErr;
}

#endif

/*** RESOURCE ACCESSOR ***/
ResourceObjectPtr EditorWindow::Resource( void )
{
	return resource;
}