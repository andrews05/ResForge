#include "PlugWindow.h"
#include "Utility.h"
#include "string.h"
extern globals g;

  /*********************/
 /* PLUG WINDOW CLASS */
/*********************/

/*** CREATOR ***/
PlugWindow::PlugWindow( FileWindowPtr ownerFile )
{
	memset( this, 0, sizeof(PlugWindow) );
	file = ownerFile;
}

/*** GET FILE WINDOW ***/
FileWindowPtr PlugWindow::File( void )
{
	return file;
}

#if !TARGET_API_MAC_CARBON

/*** INSTALL CLASSIC EVENT HANDLER ***/
void PlugWindow::InstallClassicEventHandler( ClassicEventHandlerProcPtr newHandler )
{
	handler = newHandler;
}

/*** UPDATE WINDOW ***/
OSStatus PlugWindow::Update( RgnHandle region )
{
	EventRecord event;
	event.what = updateEvt;
	event.message = (UInt32) window;
	event.when = (UInt32) region;		// note overload here
	event.where = NewPoint();
	event.modifiers = null;
	
	OSStatus error = (* handler)( &event, kEventWindowUpdate, null );
	return error;
}

/*** ACTIVATE WINDOW ***/
OSStatus PlugWindow::Activate( Boolean active )
{
	EventRecord event;
	event.what = activateEvt;
	event.message = (UInt32) window;
	event.when = TickCount();
	event.where = NewPoint();
	event.modifiers = null;
	
	OSStatus error = (* handler)( &event, active? kEventWindowActivated:kEventWindowDeactivated, null );
	return error;
}

/*** CLOSE WINDOW ***/
OSStatus PlugWindow::Close( void )
{
	EventRecord event;
	event.what = mouseUp;
	event.message = (UInt32) window;
	event.when = TickCount();
	event.where = NewPoint();
	event.modifiers = null;
	
	OSStatus error = (* handler)( &event, kEventWindowClose, null );
	return error;
}

/*** HANDLE CLICK IN WINDOW ***/
OSStatus PlugWindow::Click( Point mouse, EventModifiers modifiers )
{
	EventRecord event;
	event.what = mouseDown;
	event.message = (UInt32) window;
	event.when = TickCount();
	event.where = mouse;
	event.modifiers = modifiers;
	
	OSStatus error = (* handler)( &event, kEventWindowClickContentRgn, null );
	return error;
}

#endif

/*** ACCESSORS ***/
void	PlugWindow::SetRefCon( UInt32 value )	{	refcon = value;	}
UInt32	PlugWindow::GetRefCon( void )			{	return refcon;	}
