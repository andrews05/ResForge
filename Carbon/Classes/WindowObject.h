#include "ResKnife.h"

#ifndef _ResKnife_WindowObject_
#define _ResKnife_WindowObject_

/*!
 *	@header			WindowObject
 *	@discussion		The base class for all windows in the program. Also declares the (very simple) PlugWindow subclass.
 */

/*!
 *	@class			WindowObject
 *	@abstract		Base class for all windows in the program.
 *	@discussion		Mainly consisting of regular controls such as scroll bars and headers, this doesn't do much by it's self.
 */
class WindowObject
{
	// data
protected:
/*!	@var window			Stores the Mac OS <tt>WindowRef</tt> pertaining to this window.	*/
	WindowRef			window;
/*!	@var header			Header control (the grey bar at the top of most windows).	*/
	ControlRef			header;
/*!	@var leftText		Left hand side static text control (in the header).	*/
	ControlRef			left;
/*!	@var rightText		Right hand side static text control (in the header).	*/
	ControlRef			right;
#if !TARGET_API_MAC_CARBON
/*!	@var horizScroll	Horizontal scrollbar at the bottom of most windows	*/
	ControlRef			horizScroll;
/*!	@var vertScroll		Vetical scrollbar down the right side of most windows	*/
	ControlRef			vertScroll;
/*!	@var themeSavvy		True if this window is using an Appearance Manager WDEF. (Also used to determine if Appearance controls should be drawn if this window.)	*/
	Boolean				themeSavvy;
#endif
	
public:
	// methods
/*!
 *	@function			WindowObject
 *	@discussion			Constructor function.
 */
						WindowObject( void );
/*!
 *	@function			WindowObject
 *	@discussion			Desturctor function.
 */
	virtual				~WindowObject( void );
/*!
 *	@function			Window
 *	@discussion			Accessor for the object&rsquo;s <tt>WindowRef</tt>.
 */
	virtual WindowRef	Window( void );
/*!
 *	@function			BoundsChanging
 */
	virtual OSStatus	BoundsChanging( EventRef event );
/*!
 *	@function			BoundsChanged
 */
	virtual OSStatus	BoundsChanged( EventRef event );
#if !TARGET_API_MAC_CARBON
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
 *	@function			UpdateScrollBars
 */
	virtual OSStatus	UpdateScrollBars( void );
/*!
 *	@function			Click
 */
	virtual OSStatus	Click( Point mouse, EventModifiers modifiers );
#endif
};

#endif
