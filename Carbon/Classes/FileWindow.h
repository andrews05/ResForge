#include "ResKnife.h"
#include "WindowObject.h"

#ifndef _ResKnife_FileWindow_
#define _ResKnife_FileWindow_

/*!
	@header			FileWindow
	@discussion		The bulk of the ResKnife code is concerned with the managment of this window. It is the essence of the program.
*/

/* Constants */
const UInt16 kDefaultHeaderHeight		= 20;
const UInt16 kMinimumFileWindowWidth	= 128;
const UInt16 kDefaultFileWindowWidth	= 420;
const UInt16 kMinimumFileWindowHeight	= 128 + kDefaultHeaderHeight;
const UInt16 kDefaultFileWindowHeight	= 384 + kDefaultHeaderHeight;
const UInt16 kBevelButtonHeight			= 20;
const UInt16 kFileWindowHeaderHeight	= kDefaultHeaderHeight + kBevelButtonHeight;
const UInt16 kFileWindowRowHeight		= 19;
const UInt16 kFileWindowTextHeight		= kFileWindowRowHeight - 5;

const UInt16 kFileWindowMinimumNameColumnWidth = 150;
const UInt16 kFileWindowDefaultNameColumnWidth = 250;
const UInt16 kFileWindowTypeColumnWidth		= 52;
const UInt16 kFileWindowIDColumnWidth		= 52;
const UInt16 kFileWindowSizeColumnWidth		= 52;
const UInt16 kFileWindowAttributesColumnWidth = 120;
const UInt16 kFileWindowSortColumnWidth		= 16;
const UInt16 kFileWindowAllOtherColumnWidths = kFileWindowTypeColumnWidth + kFileWindowIDColumnWidth + kFileWindowSizeColumnWidth + kFileWindowAttributesColumnWidth +8;	// excludes variable with name column

const UInt16 kFileWindowNameColumnTextOffset = 42;	// start of text, actual column starts at zero
const UInt16 kFileWindowTypeColumnOffset	= 0;	// offset from end of name column
const UInt16 kFileWindowIDColumnOffset		= kFileWindowTypeColumnOffset + kFileWindowTypeColumnWidth;
const UInt16 kFileWindowSizeColumnOffset	= kFileWindowIDColumnOffset + kFileWindowIDColumnWidth;
const UInt16 kFileWindowAttributesColumnOffset = kFileWindowSizeColumnOffset + kFileWindowSizeColumnWidth;

const UInt32 kWindowPropertyDataBrowser		= FOUR_CHAR_CODE('brow');
const UInt32 kHeaderSignature				= FOUR_CHAR_CODE('head');
const UInt32 kLeftTextSignature				= FOUR_CHAR_CODE('left');
const UInt32 kRightTextSignature			= FOUR_CHAR_CODE('rght');
const UInt32 kDataBrowserSignature			= FOUR_CHAR_CODE('brow');
const UInt32 kDataBrowserNameColumn			= FOUR_CHAR_CODE('name');
const UInt32 kDataBrowserTypeColumn			= FOUR_CHAR_CODE('type');
const UInt32 kDataBrowserIDColumn			= FOUR_CHAR_CODE('id  ');
const UInt32 kDataBrowserSizeColumn			= FOUR_CHAR_CODE('size');

typedef enum
{
	kSortName = 1,
	kSortType,
	kSortID,
	kSortSize,
	kSortAttrs
}	SortOrder;

/*** FILE WINDOW CLASS ***/
class FileWindow : WindowObject
{
	// file info
	FSSpecPtr			fileSpec;		// user's copy
	FSSpecPtr			tempSpec;		// my copy
	Boolean				fileExists;		// existing file was opened or file has been saved at some point
	Boolean				fileDirty;		// temp file ­ real file => save available
	Boolean				rfBased;		// file's resource map came from it's resource fork
	
	// resource info
	UInt16				numTypes;
	UInt32				numResources;
#if !TARGET_API_MAC_CARBON
	UInt32				numSelected;	// for fake data browser
#endif
	Handle				dataFork;		// bug: what is this for?
	ResourceObjectPtr	resourceMap;
	
	// controls
#if TARGET_API_MAC_CARBON
	ControlRef			dataBrowser;		// header controls in WindowObject
#else	// make a fake databrowser
	SortOrder			sortOrder;			// the one which is actually selected
	ControlRef			sortName;
	ControlRef			sortType;
	ControlRef			sortID;
	ControlRef			sortSize;
	ControlRef			sortAttrs;
	ControlRef			sortDir;
	SInt16				nameColumnWidth;	// varies with window size, and needs to be signed
#endif
	
	/* methods */
public:
						FileWindow( FSSpecPtr spec = null );
	virtual				~FileWindow( void );
	// overridden inherited functions
/*!
 *	@function			Window
 *	@discussion			Accessor for the object&rsquo;s <tt>WindowRef</tt>.
 */
	virtual WindowRef	Window( void );
	virtual OSStatus	BoundsChanging( EventRef event );
	virtual OSStatus	BoundsChanged( EventRef event );
#if !TARGET_API_MAC_CARBON
	virtual OSStatus	Activate( Boolean active = true );
	virtual OSStatus	Update( RgnHandle region = null );
	virtual OSStatus	Click( Point mouse, EventModifiers modifiers );
	
	// drawing
private:
	virtual OSStatus	UpdateScrollBars( void );
	OSStatus			DrawResourceIcon( ResourceObjectPtr resource, UInt16 line );
	
	// fake data brwser
	OSStatus			ClearSelection( void );
#endif
	
	// file manipulation
public:
	OSStatus			ReadResourceFork( void );
	OSStatus			ReadDataFork( OSStatus rfError );
	OSStatus			InitDataBrowser( void );
	OSStatus			SaveFile( FSSpecPtr saveSpec = null );
private:
/*!
	@function			ReadResourceMap
	@discussion			Requires the fork containing resources to be at the top of the resource chain
*/
	OSStatus			ReadResourceMap( void );	// fork-independent resource routines
	OSStatus			SaveResourceMap( void );
	
	// carbon routines
public:
	OSStatus			Zoomed( EventRef event );
	OSStatus			SetIdealSize( EventRef event );
	OSStatus			DisplaySaveDialog( void );
	OSStatus			DisplayModelessAskSaveChangesDialog( void );
	OSStatus			DisplaySaveAsDialog( void );
	OSStatus			DisplayModelessPutFileDialog( void );
	OSStatus			DisplayRevertFileDialog( void );
	OSStatus			DisplayModelessAskDiscardChangesDialog( void );
	OSStatus			DisplayNewResourceDialog( void );
	OSStatus			DisplayNewResourceSheet( void );
	
	// resource map processing
	OSStatus			CreateNewResource( ConstStr255Param name, ResType type, SInt16 resID, SInt16 attribs );
	OSStatus			OpenResource( DataBrowserItemID itemID, MenuCommand command );
private:
	OSStatus			DisposeResourceMap( void );

public:
	// sound handlers
	OSStatus			PlaySound( DataBrowserItemID itemID );
	
	// file accessors
	FSSpecPtr			GetFileSpec( void );
	void				SetFileSpec( FSSpecPtr spec );
	Boolean				IsFileDirty( void );
	void				SetFileDirty( Boolean dirty = true );
#if TARGET_API_MAC_CARBON
	ControlRef			GetDataBrowser( void );
#endif
	
	// resource accessors
	UInt32				GetResourceCount( ResType wanted = 0x00000000 );
	ResourceObjectPtr	GetResource( DataBrowserItemID itemID );
	UInt8*				GetResourceName( DataBrowserItemID itemID );
	UInt32				GetResourceSize( DataBrowserItemID itemID );
	ResType				GetResourceType( DataBrowserItemID itemID );
	SInt16				GetResourceID( DataBrowserItemID itemID );
	SInt16				GetResourceAttributes( DataBrowserItemID itemID );
};

/* window event handler */
pascal void				FileWindowScrollAction( ControlHandle control, SInt16 controlPart );
pascal OSStatus			FileWindowEventHandler( EventHandlerCallRef callRef, EventRef event, void *userData );
pascal OSStatus			FileWindowUpdateMenus( EventHandlerCallRef callRef, EventRef event, void *userData );
pascal OSStatus			FileWindowParseMenuSelection( EventHandlerCallRef callRef, EventRef event, void *userData );
pascal OSStatus			NewResourceEventHandler( EventHandlerCallRef callRef, EventRef event, void *userData );

#endif