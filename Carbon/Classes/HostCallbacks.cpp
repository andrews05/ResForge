#define _ResKnife_Plug_ 0
#include "HostCallbacks.h"
#include "Application.h"
#include "WindowObject.h"
#include "EditorWindow.h"
#include "PlugObject.h"
#include "Errors.h"

extern globals g;

/* window management */
Plug_WindowRef Host_RegisterWindow( Plug_PlugInRef plug, Plug_ResourceRef resource, WindowRef window )
{
	if( resource )
	{
		EditorWindowPtr plugWindow = new EditorWindow( ((ResourceObjectPtr) resource)->File(), (ResourceObjectPtr) resource, window );
		((PlugObjectPtr) plug)->SetWindowObject( (WindowObjectPtr) plugWindow );
		((PlugObjectPtr) plug)->SetResourceObject( (ResourceObjectPtr) resource );
		return (Plug_WindowRef) plugWindow;
	}
/*	else
	{
		PickerWindowPtr plugWindow = new PickerWindow( window );
		((PlugObjectPtr) plug)->SetWindowObject( plugWindow );
		((PlugObjectPtr) plug)->SetResourceObject( (ResourceObjectPtr) resource );
		return (Plug_WindowRef) plugWindow;
	}
*/	else return null;
}

#if !TARGET_API_MAC_CARBON

void Host_InstallClassicWindowEventHandler( Plug_WindowRef plugWindow, RoutineDescriptor *handler )
{
	((PlugWindowPtr) plugWindow)->InstallClassicEventHandler( (ClassicEventHandlerProcPtr) handler );
}

#endif

WindowRef Host_GetWindowRefFromPlugWindow( Plug_WindowRef plugWindow )
{
	return ((WindowObjectPtr) plugWindow)->Window();
}

Plug_WindowRef Host_GetPlugWindowFromWindowRef( WindowRef window )
{
	return (Plug_WindowRef) GetWindowRefCon(window);
}

Plug_PlugInRef Host_GetPlugRef( WindowRef window )
{
	#pragma unused( window )
	return null;
}

Plug_ResourceRef Host_GetTargetResource( Plug_WindowRef plugWindow )
{
	return (Plug_ResourceRef) ((EditorWindowPtr) plugWindow)->Resource();
}

/* accessors */
Handle Host_GetResourceData( Plug_ResourceRef resource )
{
	((ResourceObjectPtr) resource)->Retain();
	return ((ResourceObjectPtr) resource)->Data();
}

Handle Host_GetPartialResourceData( Plug_ResourceRef resource, UInt32 offset, UInt32 length )
{
	#pragma unused( resource, offset, length )
	return null;
}

void Host_ReleaseResourceData( Plug_ResourceRef resource )
{
	#pragma unused( resource )
//	((ResourceObjectPtr) resource)->Release();
	return;
}

void Host_ReleasePartialResourceData( Plug_ResourceRef resource, Handle data )
{
	#pragma unused( resource, data )
	return;
}

ResType Host_GetResourceType( Plug_ResourceRef resource )
{
	return ((ResourceObjectPtr) resource)->Type();
}

SInt16 Host_GetResourceID( Plug_ResourceRef resource )
{
	return ((ResourceObjectPtr) resource)->ID();
}

UInt32 Host_GetResourceSize( Plug_ResourceRef resource )
{
	return ((ResourceObjectPtr) resource)->Size();
}

void Host_GetResourceName( Plug_ResourceRef resource, Str255 name )
{
	#pragma unused( resource, name )
	return;
}

UInt32 Host_GetWindowRefCon( Plug_WindowRef plugWindow )
{
	return ((PlugWindowPtr) plugWindow)->GetRefCon();
}

void Host_SetWindowRefCon( Plug_WindowRef plugWindow, UInt32 value )
{
	((PlugWindowPtr) plugWindow)->SetRefCon(value);
}

UInt32 Host_GetGlobalRefCon( Plug_PlugInRef plug )
{
	return ((PlugObjectPtr) plug)->GetRefCon();
}

void Host_SetGlobalRefCon( Plug_PlugInRef plug, UInt32 value )
{
	((PlugObjectPtr) plug)->SetRefCon(value);
}

Boolean Host_GetResourceDirty( Plug_ResourceRef resource )
{
	return ((ResourceObjectPtr) resource)->Dirty();
}

void Host_SetResourceDirty( Plug_ResourceRef resource, Boolean dirty )
{
	((ResourceObjectPtr) resource)->SetDirty( dirty );
}

/* utilities */
Handle Host_GetDefaultTemplate( ResType type )
{
	short savedResFile = CurResFile();
	UseResFile( g.appResFile );
	Str255 name = "\pxxxx";
	BlockMoveData( &type, name +1, sizeof(ResType) );
	Handle tmpl = Get1NamedResource( 'TMPL', name );
	OSStatus error = ResError();
	UseResFile( savedResFile );
	if( error ) return null;
	else return tmpl;
}

void Host_AppendMenuToBar( Plug_PlugInRef plug, SInt16 resID )
{
	#pragma unused( plug, resID )
	return;
}

void Host_RemoveMenuFromBar( Plug_PlugInRef plug, SInt16 resID )
{
	#pragma unused( plug, resID )
	return;
}

void Host_UpdateMenus( Plug_ResourceRef resource )
{
	OSStatus error = noErr;
#if TARGET_API_MAC_CARBON
	error = CarbonEventUpdateMenus( null, null, null );
//	if( error ) DebugError( "\pHost_UpdateMenus hit an error when calling CarbonEventUpdateMenus()" );
	error = FileWindowUpdateMenus( null, null, ((ResourceObjectPtr) resource)->File() );
//	if( error ) DebugError( "\pHost_UpdateMenus hit an error when calling FileWindowUpdateMenus()" );
#else
	UpdateMenus( ((ResourceObjectPtr) resource)->File()->Window() );
#endif
}

void Host_DisplayError( ConstStr255Param errorStr, ConstStr255Param explanationStr, UInt8 severity )
{
	#pragma unused( severity )
	DisplayError( errorStr, explanationStr );
}

void Host_DebugError( ConstStr255Param errorStr, OSStatus number )
{
	DebugError( errorStr, number );
}