#include "ResKnife.h"
#include "FileWindow.h"	// for friends

#ifndef _ResKnife_ResourceObject_
#define _ResKnife_ResourceObject_

/*!
	@header			ResourceObject
	@discussion		Contains all required information for a resource, including it's parent file and whether or not it has been edited since it was last saved (if ever).
*/

/*!
	@class			ResourceObject
	@abstract		Opaque
	@discussion		Mainly consisting of regular controls such as scroll bars and headers, this doesn't do much by it's self.
*/
class ResourceObject
{
/*!	@var file		The parent file into which this resource is to be saved. */
	FileWindowPtr	file;
/*!	@var next		the next resource. */
	ResourceObjectPtr next;
	
	// status of resource
//	Boolean			neverSaved;	// resource has never been saved				-- cleared on SaveFile()
/*!	@var dirty		Resource has been modified since the file was last saved if this flag is true. Cleared when SaveFile() is called. */
	UInt16			retainCount;	// counts the number of times this resource has been loaded minus the number it's been released
	Boolean			dirty;
//	Boolean			update;		// resource is not synched with temporary file	-- cleared on UpdateFile()
	Boolean			dataFork;	// resource represents data fork, only true in files whose resource map is in the resource fork
/*!	@var number		Item number in the data browser. Deleted resources vacate their number, and it is not replaced if a new resource is created. New resources are appended to the end of the chain, and will always have the highest numbers. */
	DataBrowserItemID number;
	
	// classic display parameters
/*!	@var nameIconRgn */
	RgnHandle		nameIconRgn;
/*!	@var selected */
	Boolean			selected;
	
	// resource
/*!	@var type */
	ResType			type;
/*!	@var size */
	SInt32			size;
/*!	@var resID */
	SInt16			resID;
/*!	@var attribs */
	SInt16			attribs;
/*!	@var data		The actual resource byte stream. */
	Handle			data;
/*!	@var name */
	Str255			name;
	
	/* methods */
public:
/*!
	@function		ResourceObject
	@discussion		Creator function.
*/
					ResourceObject( FileWindowPtr owner = null );
/*!
	@function		~ResourceObject
	@discussion		Destructor function.
*/
					~ResourceObject( void );
/*!
	@function		Retain
	@discussion		Accessor function.
*/
	OSStatus		Retain( void );
/*!
	@function		Release
	@discussion		Accessor function.
*/
	void			Release( void );
/*!
	@function		File
	@discussion		Accessor function.
*/
	FileWindowPtr	File( void );
/*!
	@function		Next
	@discussion		Accessor function.
*/
	ResourceObjectPtr Next( void );
/*!
	@function		SetDirty
	@discussion		Accessor function.
*/
	void			SetDirty( Boolean value );
/*!
	@function		Dirty
	@discussion		Accessor function.
*/
	Boolean			Dirty( void );
/*!
	@function		Select
	@discussion		Accessor function.
	@param select	Pass true to select, false to deselect this resource in the file window.
*/
	void			Select( Boolean select );
/*!
	@function		Selected
	@discussion		Accessor function.
*/
	Boolean			Selected( void );
/*!
	@function		Number
	@discussion		Accessor function.
*/
	DataBrowserItemID Number( void );
/*!
	@function		RepresentsDataFork
	@discussion		Accessor function.
*/
	Boolean			RepresentsDataFork( void );
/*!
	@function		Data
	@discussion		Accessor function. Warning: This functions returns the ACTUAL data handle - do not dispose of it.
*/
	Handle			Data( void );
/*!
	@function		Name
	@discussion		Accessor function.
*/
	UInt8*			Name( void );
/*!
	@function		Size
	@discussion		Accessor function.
*/
	UInt32			Size( void );
/*!
	@function		Type
	@discussion		Accessor function.
*/
	ResType			Type( void );
/*!
	@function		ID
	@discussion		Accessor function.
*/
	SInt16			ID( void );
/*!
	@function		Attributes
	@discussion		Accessor function.
*/
	SInt16			Attributes( void );
	
	friend OSStatus FileWindow::ReadResourceMap( void );
	friend OSStatus FileWindow::ReadDataFork( OSStatus RFError );
	friend OSStatus FileWindow::InitDataBrowser( void );
#if !TARGET_API_MAC_CARBON
	friend OSStatus FileWindow::Click( Point mouse, EventModifiers modifiers );
	friend OSStatus FileWindow::DrawResourceIcon( ResourceObjectPtr resource, UInt16 line );
#endif
	friend OSStatus FileWindow::CreateNewResource( ConstStr255Param name, ResType type, SInt16 resID, SInt16 attribs );
	friend OSStatus FileWindow::DisposeResourceMap( void );
};

#endif