#include "ResKnife.h"
#include "PlugWindow.h"

#ifndef _ResKnife_PickerWindow_
#define _ResKnife_PickerWindow_

/*!
	@header			PickerWindow
	@discussion		A class specifically designed to maintain an external picker window.
*/

/*!
	@class			PickerWindow
	@discussion		A class specifically designed to maintain an external picker window.
*/
class PickerWindow : PlugWindow
{
public:
// methods
				PickerWindow( FileWindowPtr ownerFile, ResType resType );
};

#endif