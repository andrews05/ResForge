#include "ResourceObject.h"
#include "Errors.h"
#include "string.h"

/*** CREATOR ***/
ResourceObject::ResourceObject( FileWindowPtr owner )
{
	// set contents to zero
	memset( this, 0, sizeof(ResourceObject) );
	
	file = owner;
	nameIconRgn = NewRgn();
}

/*** DESTRUCTOR ***/
ResourceObject::~ResourceObject( void )
{
	if( nameIconRgn )	DisposeRgn( nameIconRgn );
	if( data )			DisposeHandle( data );
}

/*** RETAIN ***/
OSStatus ResourceObject::Retain( void )
{
	OSStatus error = noErr;
/*	if( retainCount == 0 )
	{
		if( dataFork )
		{
			// open file for reading
			SInt16 refNum;
			error = FSpOpenDF( file->GetFileSpec(), fsRdPerm, &refNum );
			if( error )
			{
				DisplayError( "\pData fork could not be read", "\pThis file appears to be corrupted. Although the resources could be read in correctly, the data fork could not be found. Please run Disk First Aid to correct the problem." );
				return error;	
			}
			
			// get new handle
			data = NewHandleClear( size );
			if( !data || MemError() )
			{
				DisplayError( "\pNot enough memory to read data fork", "\pPlease quit other applications and try again." );
				FSClose( refNum );
				return memFullErr;
			}
			
			// read data fork
			HLock( data );
			error = FSRead( refNum, (long *) &size, *data );
			HUnlock( data );
			FSClose( refNum );
		}
		else
		{
			LoadResource( data );
		}
	}
*/	retainCount++;
	return error;
}

/*** RELEASE ***/
void ResourceObject::Release( void )
{
	if( retainCount > 0 )
	{
/*		if( retainCount == 1 )
			DisposeHandle( data );
*/		retainCount--;
	}
}

/*** SET RESOURCE DIRTY ***/
void ResourceObject::SetDirty( Boolean value )
{
	dirty = value;
	file->SetFileDirty( value );
	
	// being here indicates the resource size parameter also needs updating
	size = GetHandleSize( data );
	
	// bug: should now tell all open copies of this resource to update themselves
}

/*** RES INFO RECORD ACCESSORS ***/
FileWindowPtr		ResourceObject::File( void )				{	return file;		}
ResourceObjectPtr	ResourceObject::Next( void )				{	return next;		}
Boolean				ResourceObject::Dirty( void )				{	return dirty;		}
void				ResourceObject::Select( Boolean select )	{	selected = select;	}
Boolean				ResourceObject::Selected( void )			{	return selected;	}
DataBrowserItemID	ResourceObject::Number( void )				{	return number;		}
Boolean				ResourceObject::RepresentsDataFork( void )	{	return dataFork;	}

Handle				ResourceObject::Data( void )				{	return data;		}
UInt8*				ResourceObject::Name( void )				{	return name;		}
UInt32				ResourceObject::Size( void )				{	return size;		}
ResType				ResourceObject::Type( void )				{	return type;		}
SInt16				ResourceObject::ID( void )					{	return resID;		}
SInt16				ResourceObject::Attributes( void )			{	return attribs;		}