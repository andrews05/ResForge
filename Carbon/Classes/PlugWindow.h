#include "ResKnife.h"
#include "WindowObject.h"

#ifndef _ResKnife_PlugWindow_
#define _ResKnife_PlugWindow_

/*!
 *	@header			PlugWindow
 *	@discussion		Declares the (very simple) PlugWindow subclass.
 */

#if !TARGET_API_MAC_CARBON

// classic event handler
typedef CALLBACK_API(OSStatus, ClassicEventHandlerProcPtr)	(EventRecord *event, UInt32 eventKind, void *userData);
typedef STACK_UPP_TYPE(ClassicEventHandlerProcPtr)			ClassicEventHandlerUPP;
enum { uppClassicEventHandlerProcInfo = 0x00000FF0 };		/* pascal 4_bytes Func(4_bytes, 4_bytes, 4_bytes) */
#ifdef __cplusplus
	inline ClassicEventHandlerUPP NewClassicEventHandlerUPP(ClassicEventHandlerProcPtr userRoutine) { return (ClassicEventHandlerUPP)NewRoutineDescriptor((ProcPtr)(userRoutine), uppClassicEventHandlerProcInfo, GetCurrentArchitecture()); }
#else
	#define NewClassicEventHandlerUPP(userRoutine) (ClassicEventHandlerUPP)NewRoutineDescriptor((ProcPtr)(userRoutine), uppClassicEventHandlerProcInfo, GetCurrentArchitecture())
#endif

#endif

/*!
 *	@class			PlugWindow
 *	@abstract		Base class for EditorWindow and PickerWindow.
 *	@discussion		Declares the classic event handler &amp; a refcon, and overrides a few classic events.
 */
class PlugWindow : public WindowObject
{
protected:
/*! @var file			The owning file of the window. */
	FileWindowPtr		file;
#if !TARGET_API_MAC_CARBON
/*! @var handler		The classic event handler used for plug windows. */
	ClassicEventHandlerProcPtr handler;
#endif
/*! @var refcon			A refcon for the plug to use. */
	UInt32				refcon;

public:
/*!
 *	@function			PlugWindow
 */
						PlugWindow( FileWindowPtr ownerFile );
/*!
 *	@function			File
 */
	FileWindowPtr		File( void );
#if !TARGET_API_MAC_CARBON
/*!
 *	@function			InstallClassicEventHandler
 */
	void				InstallClassicEventHandler( ClassicEventHandlerProcPtr newHandler );
/*!
 *	@function			Close
 */
	virtual OSStatus	Close( void );
/*!
 *	@function			Activate
 */
	virtual OSStatus	Activate( Boolean active = true );
/*!
 *	@function			Update
 */
	virtual OSStatus	Update( RgnHandle region = null );
/*!
 *	@function			Click
 */
	virtual OSStatus	Click( Point mouse, EventModifiers modifiers );
#endif
	void				SetRefCon( UInt32 value );
	UInt32				GetRefCon( void );
};

#endif
