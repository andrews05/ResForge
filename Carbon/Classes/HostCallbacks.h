#if !TARGET_API_MAC_OS8
	#include <Carbon/Carbon.h>
#endif

#ifndef _ResKnife_HostCallbacks_
#define _ResKnife_HostCallbacks_

/*!
 *	@header			Plug-in Import/Export
 *	@discussion		The only file that both plug-ins and the host should include, this allows a one-to-one mapping between exported and imported functions.
 */

/*!
 *	@typedef		Plug_PlugInRef
 *	@abstract		A global reference to your plug-in.
 *	@discussion		When you plug-in is first loded it is assigned a unique reference number. This allows you to maintain a global refcon into which you can save a pointer to your globals. Thus any change to preferences can be maintained across all of your open editors, even if they are editing resources in different files, and is persistant across the entire time the host remains running.
 */
typedef struct OpaquePlugInObject*		Plug_PlugInRef;
/*!
 *	@typedef		Plug_WindowRef
 *	@abstract		A reference to one of your editor or picker windows.
 *	@discussion		The <tt>Plug_WindowRef</tt> allows a host to track your window and send it events
 */
typedef struct OpaqueWindowObject*		Plug_WindowRef;
/*!
 *	@typedef		Plug_ResourceRef
 *	@abstract		A reference to one particular resource.
 *	@discussion		Allows a plug to obtain information about <i>any</i> resource, not necessarily the one it is editing. For example, a 'TEXT' editor will probably want 'styl' resource data as well.
 */
typedef struct OpaqueResourceObject*	Plug_ResourceRef;
/*!
 *	@typedef		Plug_MenuCommand
 *	@abstract		Passed to your menu parser when the user selects something.
 *	@discussion		Contains the four-byte menu command defined in your xmnu resources or that which you chose when creating the menu in InterfaceBuilder. Only used with the <tt>Plug_HandleMenuCommand()</tt> function.
 */
typedef UInt32							Plug_MenuCommand;

// idea taken from Starry Night (thanks Tom)
#if TARGET_API_MAC_OS8
#if _ResKnife_Plug_								// you should #define this to be 1É
	#define ResCall		__declspec(dllimport)	//	functions exported by the host
	#define ResCallBack	__declspec(dllexport)	//	functions exported by the plug-in
#else											// Éthe host #defines 0
	#define ResCall		__declspec(dllexport)
	#define ResCallBack	__declspec(dllimport)
#endif
#else
	#define ResCall
	#define ResCallBack
#endif

/*!
 *	@enum			EditorType
 *	@discussion		Allows a plug-in to tell the host what it does in a consice and simple way.
 */
typedef enum
{
	kPickerType			= FOUR_CHAR_CODE('pick'),
	kHexEditorType		= FOUR_CHAR_CODE('hexa'),	// returned ResTypes are ignored
	kNormalEditorType	= FOUR_CHAR_CODE('norm')	// requires 'kind' to be set to the appropriate ResType
}	EditorType;

/*!
 *	@enum			OpenMode
 *	@discussion		Lets the plug-in <i>influence</i> how sub-editors are chosen when the plug requests that a new editor be opened
 *						via <tt>Host_OpenEditor()</tt>. If it cannot be fulfilled, a lesser type of window will open.
 */
typedef enum
{
	kOpenUsingEditor = 0,
	kOpenUsingTemplate,
	kOpenUsingHex
}	OpenMode;

/*!
 *	@enum			Plug-in WindowKinds
 *	@discussion		ID numbers for generic plug windows.
 */
enum
{
	kPlugWindowDocument = 1000,		// your main window's windowkind is set to this by the host, do NOT change it.
	kPlugWindowAboutBox,			// windowkinds below 2000 are reserved
	kPlugWindowPreferences
};

/*** IMPORTED FUNCTIONS ***/
extern "C"						// functions beginning "Host_" are in ResKnife/Resurrection
{
/*!
 *	@function					Host_RegisterWindow
 *	@abstract					Registers plug-in windows with the host.
 *	@discussion					Plug-ins should call this function immediatly after creating a window to swap their Mac OS <tt>WindowRef</tt>
 *									for a <tt>Plug_WindowRef</tt>, which allows the host to track the window, it's contents, and to send events there.
 */
	ResCall Plug_WindowRef		Host_RegisterWindow( Plug_PlugInRef plug, Plug_ResourceRef resource, WindowRef window );
/*!
 *	@function					Host_InstallClassicWindowEventHandler
 *	@abstract					Without this, non-carbon plugs will not receive events
 *	@discussion					After regestering you window, and only if you do not have access to the Carbon routine <tt>InstallWindowEventHandler()</tt>,
 *									your plug should call this to receive events. Events sent are currently limited to:
 *						
 *									&bull; kEventWindowClickContentRgn
 */
	ResCall void				Host_InstallClassicWindowEventHandler( Plug_WindowRef plugWindow, RoutineDescriptor *handler );
/*!
 *	@function					Host_GetWindowRefFromPlugWindow
 *	@abstract					Allows plug-ins to obtain a Mac OS <tt>WindowRef</tt> from their <tt>Plug_WindowRef</tt>
 *	@discussion					This call must not be made before the window has been registered using <tt>Host_RegisterWindow()</tt>
 */
	ResCall WindowRef			Host_GetWindowRefFromPlugWindow( Plug_WindowRef plugWindow );
/*!
 *	@function					Host_GetPlugWindowFromWindowRef
 *	@abstract					Allows plug-ins to obtain a <tt>Plug_WindowRef</tt> from their Mac OS <tt>WindowRef</tt>
 *	@discussion					This call must not be made before the window has been registered using <tt>Host_RegisterWindow()</tt>
 */
	ResCall Plug_WindowRef		Host_GetPlugWindowFromWindowRef( WindowRef window );
/*!
 *	@function					Host_GetPlugRef
 *	@discussion					You will probably need to call this if the system calls one of your routines directly.
 */
	ResCall Plug_PlugInRef		Host_GetPlugRef( WindowRef window );
/*!
 *	@function					Host_GetTargetResource
 */
	ResCall Plug_ResourceRef	Host_GetTargetResource( Plug_WindowRef plugWindow );
/*!
 *	@function					Host_GetResourceData
 *	@discussion					Dispose of with <tt>Host_ReleaseResourceData()</tt>
 */
	ResCall Handle				Host_GetResourceData( Plug_ResourceRef resource );
/*!
 *	@function					Host_GetPartialResourceData
 *	@discussion					Dispose of with <tt>Host_ReleasePartialResourceData()</tt>
 */
	ResCall Handle				Host_GetPartialResourceData( Plug_ResourceRef resource, UInt32 offset, UInt32 length );
/*!
 *	@function					Host_ReleaseResourceData
 */
	ResCall	void				Host_ReleaseResourceData( Plug_ResourceRef resource );
/*!
 *	@function					Host_ReleasePartialResourceData
 */
	ResCall	void				Host_ReleasePartialResourceData( Plug_ResourceRef resource, Handle data );
/*!
 *	@function					Host_GetResourceType
 */
	ResCall ResType				Host_GetResourceType( Plug_ResourceRef resource );
/*!
 *	@function					Host_GetResourceID
 */
	ResCall SInt16				Host_GetResourceID( Plug_ResourceRef resource );
/*!
 *	@function					Host_GetResourceSize
 */
	ResCall UInt32				Host_GetResourceSize( Plug_ResourceRef resource );
/*!
 *	@function					Host_GetResourceName
 */
	ResCall void				Host_GetResourceName( Plug_ResourceRef resource, Str255 name );
/*	ResCall void				Host_SetResourceName( Plug_ResourceRef resource, ConstStr255Param name );	*/
/*!
 *	@function					Host_GetResourceDirty
 */
	ResCall Boolean				Host_GetResourceDirty( Plug_ResourceRef resource );
/*!
 *	@function					Host_SetResourceDirty
 */
	ResCall void				Host_SetResourceDirty( Plug_ResourceRef resource, Boolean dirty );
/*	ResCall Boolean				Host_GetResourceIsOnDisk( Plug_ResourceRef resource );		*/				// name may change soon
/*!
 *	@function					Host_GetWindowRefCon
 */
	ResCall UInt32				Host_GetWindowRefCon( Plug_WindowRef plugWindow );
/*!
 *	@function					Host_SetWindowRefCon
 */
	ResCall void				Host_SetWindowRefCon( Plug_WindowRef plugWindow, UInt32 value );
/*!
 *	@function					Host_GetGlobalRefCon
 */
	ResCall UInt32				Host_GetGlobalRefCon( Plug_PlugInRef plugRef );
/*!
 *	@function					Host_SetGlobalRefCon
 */
	ResCall void				Host_SetGlobalRefCon( Plug_PlugInRef plugRef, UInt32 value );
/*	ResCall OSStatus			Host_OpenEditor( Plug_ResourceRef resource, ResOpenMode mode );
	ResCall OSStatus			Host_SaveResource( Plug_ResourceRef resource );							// VERY IMPORTANT CALL! - Make when closing window
	ResCall void				Host_SetCursor( Plug_PlugInRef plugRef, Cursor *cursor );
	ResCall void				Host_SetCursorToID( Plug_PlugInRef plugRef, SInt16 resID );
*/
/*!
 *	@function					Host_GetDefaultTemplate
 *	@abstract					Returns the default TMPL resource for the resource type passed in.
 *	@discussion					Handle is <tt>NULL</tt> if no template exists. You must dispose of the handle yourself.
 */
	ResCall Handle				Host_GetDefaultTemplate( ResType type );
/*!
 *	@function					Host_AppendMenuToBar
 *	@discussion					The host will track your window, and hide the menu when you are not fromtmost.
 */
	ResCall void				Host_AppendMenuToBar( Plug_PlugInRef plug, SInt16 resID );
/*!
 *	@function					Host_RemoveMenuFromBar
 */
	ResCall void				Host_RemoveMenuFromBar( Plug_PlugInRef plug, SInt16 resID );
/*!
 *	@function					Host_UpdateMenus
 */
	ResCall void				Host_UpdateMenus( Plug_ResourceRef resource );
/*!
 *	@function					Host_DisplayError
 *	@discussion					Errors the user should see
 */
	ResCall void				Host_DisplayError( ConstStr255Param error, ConstStr255Param explanation, UInt8 severity );
/*!
 *	@function					Host_DebugError
 *	@discussion					Errors the user shouldn't see
 */
	ResCall void				Host_DebugError( ConstStr255Param error, OSStatus number );
}

/*** EXPORTED FUNCTIONS ***/
extern "C"						// functions beginning "Plug_" should be in your plug-in editor
{
	/* required functions - plug-in won't be loaded if all these symbols cannot be found */
/*	ResCallBack OSStatus		Plug_EditorType( Plug_PlugInRef plugRef, EditorType *type, ResType *kind, UInt8 *number );			// called to identify the number of different types of resources it can handle
*/
/*!
 *	@function					Plug_InitInstance
 *	@abstract					Allows a plug-in to initalise itself and prepare to edit the resource.
 *	@discussion					This is a required call. You must export this for your plug-in to be loaded.
 *	@param plug					A reference which has been assigned to this plug-in. It will not necessarily remain constant, so do not save it beyond this call returning.
 *	@param resource				A reference to the resource whose editing session has been requested.
 */
	ResCallBack	OSStatus		Plug_InitInstance( Plug_PlugInRef plug, Plug_ResourceRef resource );
/*	ResCallBack OSStatus		Plug_FlattenResource( Plug_PlugInRef plugRef, Plug_ResourceRef resource );			// update the handle provided by the host (see Host_GetResData)
	ResCallBack OSStatus		Plug_ResourceChanged( Plug_PlugInRef plugRef, Plug_ResourceRef resource );			// another editor has changed the resource your working on (normally responded to by calling Host_GetResData and a window update)
*/	/* optional functions - only called if they are requested & found */
/*	ResCallBack OSStatus		Plug_UpdateMenu( Plug_PlugInRef plugRef, Plug_WindowRef windowObject );
	ResCallBack OSStatus		Plug_HandleMenuCommand( Plug_PlugInRef plugRef, Plug_MenuCommand menuCmd, Boolean *handled );
	ResCallBack OSStatus		Plug_HandleMenuItem( Plug_PlugInRef plugRef, SInt16 menuID, SInt16 itemID, Boolean *handled );	// name change
	ResCallBack OSStatus		Plug_AboutBox( Plug_PlugInRef plugRef );
*/}

#endif