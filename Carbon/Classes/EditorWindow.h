#include "ResKnife.h"
#include "PlugWindow.h"
#include "ResourceObject.h"

#ifndef _ResKnife_EditorWindow_
#define _ResKnife_EditorWindow_

/*!
 *	@header			EditorWindow
 *	@discussion		A class specifically designed to maintain an external editor window.
 */

/*!
 *	@class			EditorWindow
 *	@discussion		A class specifically designed to maintain an external editor window.
 */
class EditorWindow : PlugWindow
{
private:
	ResourceObjectPtr	resource;
	Boolean				modified;	// flag the editor sets when it modifies a resource (ie. it needs to be saved)
	
public:
/*!
 *	@function		EditorWindow
 *	@discussion		Constructor function.
 */
						EditorWindow( FileWindowPtr ownerFile, ResourceObjectPtr targetResource, WindowRef inputWindow );
/*!
 *	@function		Close
 *	@discussion		Sends a close message to the plug, then closes the window.
 */
	OSStatus			Close( void );
	ResourceObjectPtr	Resource( void );
};

#endif