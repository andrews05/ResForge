#include "WindowObject.h"

/*** CONSTRUCTOR ***/
WindowObject::WindowObject( void )
{
	memset( this, 0, sizeof(WindowObject) );
}

/*** DESTRUCTOR ***/
WindowObject::~WindowObject( void )
{
	if( window )
	{
		HideWindow( window );
		DisposeWindow( window );
	}
}

/*** WINDOW ACCESSOR ***/
WindowRef WindowObject::Window( void )
{
	return window;
}

/*** WINDOW BOUNDS ARE CHANGING ***/
OSStatus WindowObject::BoundsChanging( EventRef event )
{
	#pragma unused( event )
	return eventNotHandledErr;
}

/*** WINDOW BOUNDS HAVE CHANGED ***/
OSStatus WindowObject::BoundsChanged( EventRef event )
{
	#pragma unused( event )
	return eventNotHandledErr;
}

#if !TARGET_API_MAC_CARBON

/*** CLOSE ***/
OSStatus WindowObject::Close( void )
{
	delete this;
	return noErr;
}

/*** ACTIVATE ***/
OSStatus WindowObject::Activate( Boolean active )
{
	#pragma unused( active )
	return eventNotHandledErr;
}

/*** UPDATE ***/
OSStatus WindowObject::Update( RgnHandle region )
{
	#pragma unused( region )
	return eventNotHandledErr;
}

/*** UPDATE SCROLL BARS ***/
OSStatus WindowObject::UpdateScrollBars( void )
{
	return eventNotHandledErr;
}

/*** MOUSE CLICK ***/
OSStatus WindowObject::Click( Point mouse, EventModifiers modifiers )
{
	#pragma unused( mouse, modifiers )
	return eventNotHandledErr;
}

#endif
