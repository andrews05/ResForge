#include "ResKnife.h"
#include "WindowObject.h"

/*!
	@header			InspectorWindow
	@discussion		Manages the little inspector that accompanies a File Window.
*/

/* INSPECTOR WINDOW CLASS */
class InspectorWindow : WindowObject
{
public:
						InspectorWindow( void );
						~InspectorWindow( void );
	virtual OSStatus	Update( RgnHandle region = null );	// unused parameter
};

pascal OSStatus CloseInspectorWindow( EventHandlerCallRef callRef, EventRef event, void *userData );

// inspector window dimentions
const UInt16 kInspectorHeaderHeight		= 48 + 4;	// 48 for huge icon
const UInt16 kInspectorWindowWidth		= 183;
const UInt16 kInspectorWindowHeight		= 183;

// non-window dimentions
const UInt16 kControlCheckBoxHeight		= 16;
