#include "ResKnife.h"
#include "WindowObject.h"
#include "ResourceObject.h"

#ifndef _ResKnife_PlugObject_
#define _ResKnife_PlugObject_

/*!
	@header			PlugObject
	@discussion		Keeps track of all loaded plug-ins.
*/

/*!
	@class			PlugObject
	@abstract		Contains the data required to know which plug-ins can edit what.
	@discussion		Created when a plug-in is loaded for the first time, and is never destoyed, this class maintains the connection between the host and a plug-in. Also tracks whether the plug is an Editor or a Picker.
*/
typedef class PlugObject
{
/*!	@var connID			A CFM connection ID to a plug-in. */
	CFragConnectionID	connID;
/*!	@var windowObj		The first window loaded for this plug-in. Either a PickerWindow or an EditorWindow. */
	WindowObjectPtr		windowObj;
/*!	@var resourceObj	What the first loaded window edits (if anything). */
	ResourceObjectPtr	resourceObj;
//	EditorType			editorType;
/*!	@var ResType		The type of resource this plug can handle. */
	ResType				whatIActuallyEdit;
	
	// for the plug's use
/*!	@var refcon			A plug-global refcon for storing (say) it's preferences structure. */
	UInt32				refcon;
	
public:
/*!
	@function		GetConnectionID
	@discussion		Accessor function.
*/
	CFragConnectionID	GetConnectionID( void );
/*!
	@function		SetConnectionID
	@discussion		Accessor function.
*/
	void				SetConnectionID( CFragConnectionID newID );
/*!
	@function		GetWindowObject
	@discussion		Accessor function.
*/
	WindowObjectPtr		GetWindowObject( void );
/*!
	@function		SetWindowObject
	@discussion		Accessor function.
*/
	void				SetWindowObject( WindowObjectPtr newWindowObj );
/*!
	@function		GetResourceObject
	@discussion		Accessor function.
*/
	ResourceObjectPtr	GetResourceObject( void );
/*!
	@function		SetResourceObject
	@discussion		Accessor function.
*/
	void				SetResourceObject( ResourceObjectPtr newResourceObj );
/*!
	@function		SetRefCon
	@discussion		Accessor function.
*/
	void				SetRefCon( UInt32 value );
/*!
	@function		GetRefCon
	@discussion		Accessor function.
*/
	UInt32				GetRefCon( void );
}	PlugObject,			*PlugObjectPtr;

/*!
	@function		LoadEditor
	@discussion		Loads a CFrag by name, and passes it a resource to edit.
	@param resource	The resource to be edited.
	@param libName	A string containing the fragment name of the editor to be used, for example "icns Editor" or "PICT Picker".
*/
OSStatus LoadEditor( ResourceObjectPtr resource, ConstStr63Param libName );
/*!
	@function		UnloadEditor
	@discussion		Unloads the given plug.
	@param plug		The plug-in to be killed.
*/
OSStatus UnloadEditor( PlugObjectPtr plug );

/*!
	@typedef		InitPlugProcPtr
	@discussion		The pointer to Plug_InitInstance() that FindSymbol returns.
*/
typedef OSStatus (* InitPlugProcPtr)( PlugObjectPtr plug, ResourceObjectPtr resource );

#endif