#include "PlugObject.h"
#include "Errors.h"
extern globals g;

/*** LOAD EDITOR ***/
OSStatus LoadEditor( ResourceObjectPtr resource, ConstStr63Param libName )
{
	// create editor window structure and save resource to be edited into it
	OSStatus error = noErr;
	PlugObjectPtr plug = (PlugObjectPtr) NewPtrClear( sizeof(PlugObject) );	// bug: this function calls itself, so memory leak may exist here
	if( !plug ) return memFullErr;											//	another bug: should check if plug already has associated PlugObject (ie it is loaded already) - globalRefCon won't work
	
	
	// load editor's library into memory
	CFragConnectionID	connID = null;
	Ptr					mainAddr = null;
	Str255				errMessage;
	error = GetSharedLibrary( libName, kPowerPCCFragArch, kLoadCFrag, &connID, &mainAddr, errMessage );
	DebugError( errMessage );
	if( error )
	{
		if( EqualString( libName, "\pHex Editor", true, true ) )
		{
			DisposePtr( (Ptr) plug );	// only dispose if was created just now
			DisplayError( "\pNo editors are available for this resource!", "\pI suggest you reinstall the program." );
			return error;
		}
		else if( EqualString( libName, "\pTemplate Editor", true, true ) )
		{
			error = LoadEditor( resource, "\pHex Editor" );
			return error;
		}
		else
		{
			error = LoadEditor( resource, "\pTemplate Editor" );
			if( error )
				error = LoadEditor( resource, "\pHex Editor" );
			return error;
		}
	}
	plug->SetConnectionID( connID );
	
	// find and call InitInstance symbol
	InitPlugProcPtr		symAddr;
	CFragSymbolClass	symClass;
	error = FindSymbol( connID, "\pPlug_InitInstance", (Ptr *) &symAddr, &symClass );
	if( error )
	{
		DisposePtr( (Ptr) plug );	// only dispose if was created just now
		if( g.debug )	DebugError( "\pPlug_InitInstance() could not be found." );
		else			DisplayError( "\pCannot load up requested editor.", "\pPlease obtain an update from the plug-in's author." );
		return error;
	}
	error = (* symAddr)( plug, resource );
	if( error )
	{
		DisposePtr( (Ptr) plug );	// only dispose if was created just now
		DebugError( "\pPlug_InitInstance() returned an error. This is quite normal for the Template Editor, thus if no XXXX Editor exists, and no template is found, you will see this dialog, then a hex editor appear." );
	}
	return error;
}

/*** UNLOAD EDITOR ***/
OSStatus UnloadEditor( PlugObjectPtr plug )
{
	#pragma unused( plug )
	OSStatus error = noErr;
	CFragConnectionID connID = plug->GetConnectionID();
	
	// find and call DisposeEditor symbol
/*	DisposePlugProcPtr	symAddr;
	CFragSymbolClass	symClass;
	error = FindSymbol( connID, "\pPlug_DisposeEditor", (Ptr *) &symAddr, &symClass );
	if( error ) return error;
	(* symAddr)( plug );
*/	
	// close connection to editor
	error = CloseConnection( &connID );
	plug->SetConnectionID( null );
	return error;
}

  /**************************/
 /* CLASS ACCESSOR METHODS */
/**************************/

/*** ACCESSORS ***/
void				PlugObject::SetRefCon( UInt32 value )								{	refcon = value;					}
UInt32				PlugObject::GetRefCon( void )										{	return refcon;					}
CFragConnectionID	PlugObject::GetConnectionID( void )									{	return connID;					}
void				PlugObject::SetConnectionID( CFragConnectionID newID )				{	connID = newID;					}
WindowObjectPtr		PlugObject::GetWindowObject( void )									{	return windowObj;				}
void				PlugObject::SetWindowObject( WindowObjectPtr newWindowObj )			{	windowObj = newWindowObj;		}
ResourceObjectPtr	PlugObject::GetResourceObject( void )								{	return resourceObj;				}
void				PlugObject::SetResourceObject( ResourceObjectPtr newResourceObj )	{	resourceObj = newResourceObj;	}