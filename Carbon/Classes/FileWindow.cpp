#include "FileWindow.h"
#include "Application.h"
#include "Asynchronous.h"
#include "ResourceObject.h"
#include "Errors.h"
#include "InspectorWindow.h"
#include "PlugObject.h"		// for LoadEditor()
#include "PickerWindow.h"
#include "Utility.h"
extern globals g;

#pragma mark Constructor

/*** FILE WINDOW CONSTRUCTOR ***/
FileWindow::FileWindow( FSSpecPtr spec )
{
	OSStatus error = noErr;
	
#if USE_NIBS
	// create a nib reference (only searches the application bundle)
	IBNibRef nibRef = null;
	error = CreateNibReference( CFSTR("ResKnife"), &nibRef );
	if( error != noErr || nibRef == null )
	{
		DisplayError( "\pThe nib file reference could not be obtained." );
		return;
	}
	
	// create window
	error = CreateWindowFromNib( nibRef, CFSTR("File Window"), &window );
	if( error != noErr || window == null )
	{
		DisplayError( "\pA file window could not be obtained from the nib file." );
		return;
	}
	
	// dispose of nib ref
	DisposeNibReference( nibRef );
	
#elif TARGET_API_MAC_CARBON
	// create window
	Rect creationBounds, sectRect;
	SetRect( &creationBounds, 0, 0, kDefaultFileWindowWidth, kDefaultFileWindowHeight );
	GetAvailableWindowPositioningBounds( GetMainDevice(), &sectRect );
	InsetRect( &sectRect, 0, 10 );
	SectRect( &sectRect, &creationBounds, &creationBounds );
	OffsetRect( &creationBounds, 10, 0 );
	WindowAttributes					attributes = kWindowStandardDocumentAttributes | kWindowStandardHandlerAttribute | kWindowInWindowMenuAttribute;
	if( g.systemVersion >= kMacOSX )	attributes |= kWindowLiveResizeAttribute;
	error = CreateNewWindow( kDocumentWindowClass, attributes, &creationBounds, &window );
	if( error ) return;
#else
	if( g.useAppearance && g.systemVersion >= kMacOS8 )
	{
		window = GetNewCWindow( kFileWindow8, null, kFirstWindowOfClass );
		themeSavvy = true;
	}
	else
	{
		window = GetNewCWindow( kFileWindow7, null, kFirstWindowOfClass );
		themeSavvy = false;
	}
#endif
	
	// save FileWindow class in window's refcon
	SetWindowRefCon( window, (UInt32) this );
	SetWindowKind( window, kFileWindowKind );
	SetWindowTitle( window, spec->name );
#if TARGET_API_MAC_CARBON
	// set title used in window menu
	SetWindowAlternateTitle( window, null );	// bug: should use path here
#endif
	
	// set window's background to default for theme
	if( g.useAppearance )
		SetThemeWindowBackground( window, kThemeBrushModelessDialogBackgroundActive, false );

#if USE_NIBS	// Carbon nib file on Public Beta doesn't let me set this
	WindowAttributes setThese = null, clearThese = null;
	setThese = kWindowInWindowMenuAttribute;
	ChangeWindowAttributes( window, setThese, clearThese );
#endif
	
	// initalise file variables
	fileSpec	= (FSSpecPtr) NewPtrClear( sizeof(FSSpec) );
	tempSpec	= (FSSpecPtr) NewPtrClear( sizeof(FSSpec) );
	fileDirty	= false;
	SetFileSpec( spec );
#if TARGET_API_MAC_CARBON
	dataBrowser	= null;
#endif
	
	// initalise resource variables
	numTypes	= 0;
	numResources = 0;
	dataFork	= null;
	resourceMap	= null;
	
#if TARGET_API_MAC_CARBON
	// install window event handler
	EventHandlerRef	ref			= null;
	EventHandlerUPP	handler		= NewEventHandlerUPP( FileWindowEventHandler );
	EventTypeSpec	events[]	= {	{ kEventClassWindow, kEventWindowClose },
									{ kEventClassWindow, kEventWindowBoundsChanging },
									{ kEventClassWindow, kEventWindowBoundsChanged },
									{ kEventClassWindow, kEventWindowGetIdealSize },
									{ kEventClassWindow, kEventWindowZoomed } };
	InstallWindowEventHandler( window, handler, GetEventTypeCount(events), (EventTypeSpec *) &events, this, &ref );

	EventTypeSpec update		=	{ kEventClassMenu, kEventMenuEnableItems };
	EventTypeSpec process		=	{ kEventClassCommand, kEventCommandProcess };
	
	// install menu update handler
	handler	= NewEventHandlerUPP( FileWindowUpdateMenus );
	InstallWindowEventHandler( window, handler, 1, &update, this, &ref );
	
	// install menu selection handler
	handler	= NewEventHandlerUPP( FileWindowParseMenuSelection );
	InstallWindowEventHandler( window, handler, 1, &process, this, &ref );
#endif

#if USE_NIBS
	// set window property
	ControlRef dataBrowser;
	ControlID id = { kDataBrowserSignature, 0 };
	GetControlByID( window, &id, &dataBrowser );
	SetWindowProperty( window, kResKnifeCreator, kWindowPropertyDataBrowser, sizeof(ControlRef), &dataBrowser );;

#elif TARGET_API_MAC_CARBON		// CarbonLib 1.1+ only
	// create root control
	ControlRef root;
	CreateRootControl( window, &root );
	
	// create header control
	Rect windowBounds, rect;
	GetWindowPortBounds( window, &windowBounds );
	SetRect( &rect, windowBounds.left, windowBounds.top, windowBounds.right, windowBounds.bottom );
	InsetRect( &rect, -1, -1 );
	rect.bottom = rect.top + kDefaultHeaderHeight +1;
	CreateWindowHeaderControl( window, &rect, true, &header );
	ControlID id = { kHeaderSignature, 0 };
	SetControlID( header, &id );
	
	// create text controls
	ControlFontStyleRec fontStyle;
	fontStyle.flags = kControlUseFontMask + kControlUseJustMask;
	fontStyle.font = kControlFontSmallSystemFont;
	fontStyle.just = teJustLeft;
	SetRect( &rect, windowBounds.left +4, windowBounds.top +4, (windowBounds.right - windowBounds.left) /5 *3, windowBounds.top + kDefaultHeaderHeight -4 );
	CreateStaticTextControl( window, &rect, CFSTR("left"), &fontStyle, &left );
	id.id = 0;
	id.signature = kLeftTextSignature;
	SetControlID( left, &id );
	
	fontStyle.just = teJustRight;
	SetRect( &rect, (windowBounds.right - windowBounds.left) /5 *2, windowBounds.top +4, windowBounds.right -4, windowBounds.top + kDefaultHeaderHeight -4 );
	CreateStaticTextControl( window, &rect, CFSTR("right"), &fontStyle, &right );
	id.id = 0;
	id.signature = kRightTextSignature;
	SetControlID( right, &id );
	
	// embed text controls within header
	EmbedControl( left, header );
	EmbedControl( right, header );
	
	// create data browser
	SetRect( &rect, windowBounds.left, windowBounds.top + kDefaultHeaderHeight +1, windowBounds.right, windowBounds.bottom );
	CreateDataBrowserControl( window, &rect, kDataBrowserListView, &dataBrowser );
	id.id = 0;
	id.signature = kDataBrowserSignature;
	SetControlID( dataBrowser, &id );
	SetControlReference( dataBrowser, (UInt32) this );
	SetWindowProperty( window, kResKnifeCreator, kWindowPropertyDataBrowser, sizeof(ControlRef), &dataBrowser );
	SetKeyboardFocus( window, dataBrowser, kControlDataBrowserPart );
	
#elif !TARGET_API_MAC_CARBON
	// create controls
	if( themeSavvy )
	{
		// create basic window controls
		header		= GetNewControl( kFileHeaderControl, window );
		horizScroll	= GetNewControl( kAppearanceScrollBarControl, window );
		vertScroll	= GetNewControl( kAppearanceScrollBarControl, window );

		// create sort buttons
		Rect bounds	= {};
		sortName	= NewControl( window, &bounds, "\pName",		true, 0, kControlBehaviorSticky + kControlContentTextOnly, 0, kControlBevelButtonSmallBevelProc, 0 );
		sortType	= NewControl( window, &bounds, "\pType",		true, 0, kControlBehaviorSticky + kControlContentTextOnly, 0, kControlBevelButtonSmallBevelProc, 0 );
		sortID		= NewControl( window, &bounds, "\pID",			true, 0, kControlBehaviorSticky + kControlContentTextOnly, 0, kControlBevelButtonSmallBevelProc, 0 );
		sortSize	= NewControl( window, &bounds, "\pSize",		true, 0, kControlBehaviorSticky + kControlContentTextOnly, 0, kControlBevelButtonSmallBevelProc, 0 );
		sortAttrs	= NewControl( window, &bounds, "\pAttributes",	true, 0, kControlBehaviorSticky + kControlContentTextOnly, 0, kControlBevelButtonSmallBevelProc, 0 );
		sortDir		= NewControl( window, &bounds, "\p",			true, 0, kControlContentIconSuiteRes, kSortUpIcon, kControlBevelButtonSmallBevelProc, 0 );
		nameColumnWidth = kFileWindowDefaultNameColumnWidth;
		
		// put the text in the right place
		SetBevelButtonTextAlignment( sortName,	kControlBevelButtonAlignTextFlushLeft, kFileWindowNameColumnTextOffset -1 );
		SetBevelButtonTextAlignment( sortType,	kControlBevelButtonAlignTextFlushRight, 5 );
		SetBevelButtonTextAlignment( sortSize,	kControlBevelButtonAlignTextFlushRight, 5 );
		SetBevelButtonTextAlignment( sortID,	kControlBevelButtonAlignTextFlushRight, 5 );
		SetBevelButtonTextAlignment( sortAttrs,	kControlBevelButtonAlignTextCenter, 0 );
			
		// set up font details
		ControlFontStylePtr fontStyle = (ControlFontStylePtr) NewPtrClear( sizeof(ControlFontStyleRec) );
		fontStyle->flags = kControlUseFontMask + kControlUseSizeMask;
		fontStyle->font = kControlFontSmallSystemFont;
		
		// apply font details to controls
		SetControlFontStyle( sortName, fontStyle );
		SetControlFontStyle( sortType, fontStyle );
		SetControlFontStyle( sortSize, fontStyle );
		SetControlFontStyle( sortID, fontStyle );
		SetControlFontStyle( sortAttrs, fontStyle );
			
		// depress type control
		SetControlValue( sortType, 1 );
		sortOrder = kSortType;
		
		// size the controls correctly
		MoveControl( sortName, -1, kDefaultHeaderHeight +1 );
		SizeControl( sortName, nameColumnWidth, kBevelButtonHeight );

		MoveControl( sortType, nameColumnWidth -1, kDefaultHeaderHeight +1 );
		SizeControl( sortType, kFileWindowTypeColumnWidth, kBevelButtonHeight );

		MoveControl( sortID, nameColumnWidth + kFileWindowTypeColumnWidth -1, kDefaultHeaderHeight +1 );
		SizeControl( sortID, kFileWindowIDColumnWidth, kBevelButtonHeight );

		MoveControl( sortSize, nameColumnWidth + kFileWindowTypeColumnWidth + kFileWindowIDColumnWidth -1, kDefaultHeaderHeight +1 );
		SizeControl( sortSize, kFileWindowSizeColumnWidth, kBevelButtonHeight );

		MoveControl( sortAttrs, nameColumnWidth + kFileWindowTypeColumnWidth + kFileWindowIDColumnWidth + kFileWindowSizeColumnWidth -1, kDefaultHeaderHeight +1 );
		SizeControl( sortAttrs, kFileWindowAttributesColumnWidth, kBevelButtonHeight );

		MoveControl( sortDir, nameColumnWidth + kFileWindowTypeColumnWidth + kFileWindowIDColumnWidth + kFileWindowSizeColumnWidth + kFileWindowAttributesColumnWidth -1, kDefaultHeaderHeight +1 );
		SizeControl( sortDir, kFileWindowSortColumnWidth, kBevelButtonHeight );
	}
	else
	{
		nameColumnWidth = kFileWindowDefaultNameColumnWidth;
		horizScroll	= GetNewControl( kSystem7ScrollBarControl, window );
		vertScroll	= GetNewControl( kSystem7ScrollBarControl, window );
	}
	
	// move & update scroll bars to where they should be :)
	BoundsChanged( null );
#endif
	
	// read forks into memory and
	error = ReadResourceFork();
	error = ReadDataFork( error );
	if( error )
	{
		delete this;
		return;
	}
	
#if TARGET_API_MAC_CARBON	// CarbonLib 1.1+ or OS X only
	// initalise data browser
	InitDataBrowser();
#endif
	
	// now finally we can show the window
	ShowWindow( window );
	new InspectorWindow;
}

/*** DESTRUCTOR ***/
FileWindow::~FileWindow( void )
{
	DisposeWindow( window );
	if( fileSpec )		DisposePtr( (Ptr) fileSpec );
	if( resourceMap )	DisposeResourceMap();
}

/*** WINDOW ACCESSOR ***/
WindowRef FileWindow::Window( void )
{
	return window;
}

  /********************/
 /* EVENT PROCESSING */
/********************/

#if TARGET_API_MAC_CARBON

/*** FILE WINDOW EVENT HANDLER ***/
pascal OSStatus FileWindowEventHandler( EventHandlerCallRef callRef, EventRef event, void *userData )
{
	#pragma unused( callRef )
	OSStatus		error = eventNotHandledErr;
	unsigned long	eventClass = GetEventClass( event );
	unsigned long	eventKind = GetEventKind( event );
	FileWindowPtr	file = (FileWindowPtr) userData;
	if( !file ) return eventNotHandledErr;
	
	switch( eventClass )
	{
		case kEventClassWindow:
			switch( eventKind )
			{
				case kEventWindowClose:
				{	WindowRef window = FrontNonFloatingWindow(), nextWindow;
					while( window )
					{
						nextWindow = GetNextWindow( window );
						SInt32 kind = GetWindowKind( window );
						if( kind == kPickerWindowKind || kind == kEditorWindowKind )
						{
							FileWindowPtr owner = (FileWindowPtr) ((PlugWindowPtr) GetWindowRefCon( window ))->File();
							if( owner == file )
							{
//								DisposeWindow( window );	// bug: windows didn't used to close when sent a WindowClose event! (seems to work now though)
								EventRef event;
								CreateEvent( null, kEventClassWindow, kEventWindowClose, kEventDurationNoWait, kEventAttributeNone, &event );
								SendEventToWindow( event, window );
								ReleaseEvent( event );
							}
						}
						window = nextWindow;
					}
					
					// feature to add: user chooses either resource-level or file-level (or both) save sheets
					if( file->IsFileDirty() )
						if( g.useSheets )	error = file->DisplayModelessAskSaveChangesDialog();
						else				error = file->DisplaySaveDialog();
					else error = noErr;
					if( error != userCanceledErr )
						delete file;
				}	break;
				
				case kEventWindowBoundsChanging:
					error = file->BoundsChanging( event );
					break;
				
				case kEventWindowBoundsChanged:
					error = file->BoundsChanged( event );
					break;
				
				case kEventWindowZoomed:
					error = file->Zoomed( event );
					break;
				
				case kEventWindowGetIdealSize:
					error = file->SetIdealSize( event );
					break;
			}
			break;
		
		case kEventClassCommand:		
			HICommand command;
			error = GetEventParameter( event, kEventParamDirectObject, typeHICommand, null, sizeof(HICommand), null, &command );
			if( error ) return eventNotHandledErr;
			else error = eventNotHandledErr;
			switch( eventKind )
			{
				case kEventCommandProcess:
/*					switch( command.commandID )
					{
					}
*/					break;
			}
			break;
	}
	return error;
}

/*** FILE WINDOW UPDATE MENUS ***/
pascal OSStatus FileWindowUpdateMenus( EventHandlerCallRef callRef, EventRef event, void *userData )
{
	#pragma unused( callRef, event )
	OSStatus error = eventNotHandledErr;
	
	// get file window
	FileWindowPtr file = (FileWindowPtr) userData;
	if( !file ) return eventNotHandledErr;
	
	// get number of resources selected
	UInt32 numSelected;
	GetDataBrowserItemCount( file->GetDataBrowser(), kDataBrowserNoItem, true, kDataBrowserItemIsSelected, &numSelected );
	
	// determine if selected resource is of type 'snd '
	Boolean canPlaySound = false;
	ResourceObjectPtr resource = null;
	DataBrowserItemID first, last, n;
	GetDataBrowserSelectionAnchor( file->GetDataBrowser(), &first, &last );
	if( first != kDataBrowserNoItem && last != kDataBrowserNoItem )
	{
		for( n = first; n <= last; n++ )
		{
			resource = file->GetResource( n );
			if( resource->Type() == soundListRsrc )
				canPlaySound = true;
		}
	}
	
	// edit menu
	EnableCommand( null, kHICommandUndo, false );
	EnableCommand( null, kHICommandRedo, false );
/*	EnableCommand( null, kHICommandCut, numSelected > 0 );
	EnableCommand( null, kHICommandCopy, numSelected > 0 );
	EnableCommand( null, kHICommandPaste, numSelected > 0 );
	EnableCommand( null, kHICommandClear, numSelected > 0 );
*/	EnableCommand( null, kHICommandCut, false );
	EnableCommand( null, kHICommandCopy, false );
	EnableCommand( null, kHICommandPaste, false );
	EnableCommand( null, kHICommandClear, false );
	EnableCommand( null, kHICommandSelectAll, true );
	EnableCommand( null, kMenuCommandFind, false );
	EnableCommand( null, kMenuCommandFindAgain, false );
	
	// resource menu
	EnableCommand( null, kMenuCommandNewResource, true );
	EnableCommand( null, kMenuCommandOpenHex, numSelected > 0 );
	EnableCommand( null, kMenuCommandOpenDefault, numSelected > 0 );
	EnableCommand( null, kMenuCommandOpenTemplate, numSelected > 0 );
	EnableCommand( null, kMenuCommandOpenSpecific, numSelected > 0 );
	EnableCommand( null, kMenuCommandRevertResource, numSelected > 0 );
	EnableCommand( null, kMenuCommandPlaySound, numSelected > 0 && canPlaySound );
	return eventNotHandledErr;
}

/*** FILE WINDOW PARSE MENU SELECTION ***/
pascal OSStatus FileWindowParseMenuSelection( EventHandlerCallRef callRef, EventRef event, void *userData )
{
	#pragma unused( callRef )
	
	// get menu command
	HICommand menuCommand;
	OSStatus error = GetEventParameter( event, kEventParamDirectObject, typeHICommand, null, sizeof(HICommand), null, &menuCommand );
	if( error ) return eventNotHandledErr;
	
	// get file window
	FileWindowPtr file = (FileWindowPtr) userData;
	if( !file ) return eventNotHandledErr;
	
	switch( menuCommand.commandID )
	{
		// file menu
		case kMenuCommandCloseWindow:
		case kMenuCommandCloseFile:
			EventRef event;
			CreateEvent( null, kEventClassWindow, kEventWindowClose, kEventDurationNoWait, kEventAttributeNone, &event );
			SendEventToWindow( event, file->Window() );
			ReleaseEvent( event );
			break;
		
		case kMenuCommandSaveFile:
			error = file->SaveFile( null );
			break;
		
		case kMenuCommandSaveFileAs:
			if( g.useSheets )	error = file->DisplayModelessPutFileDialog();
			else				error = file->DisplaySaveAsDialog();
			break;
		
		case kMenuCommandRevertFile:
			if( g.useSheets )	error = file->DisplayModelessAskDiscardChangesDialog();
			else				error = file->DisplayRevertFileDialog();
			break;
		
		// edit menu
/*		case kHICommandOK:
		case kHICommandCancel:
		case kHICommandQuit:
		case kHICommandUndo:
		case kHICommandRedo:
		case kHICommandCut:
		case kHICommandCopy:
		case kHICommandPaste:
		case kHICommandClear:
*/		case kHICommandSelectAll:
			ForEachDataBrowserItem( file->GetDataBrowser(), kDataBrowserNoItem, true, kDataBrowserItemIsSelected, null, null );
  			break;
/*		case kHICommandHide:
		case kHICommandPreferences:
		case kHICommandZoomWindow:
		case kHICommandMinimizeWindow:
		case kHICommandArrangeInFront:
		case kHICommandAbout:
			break;
*/		
		// resource menu
		case kMenuCommandNewResource:
			if( g.useSheets )	error = file->DisplayNewResourceSheet();
			else				error = file->DisplayNewResourceDialog();
			break;
			
		case kMenuCommandOpenDefault:
		case kMenuCommandOpenTemplate:
		case kMenuCommandOpenSpecific:
		case kMenuCommandOpenHex:
#if TARGET_API_MAC_CARBON
			for( DataBrowserItemID item = 1; item <= file->GetResourceCount(); item++ )
			{
				if( IsDataBrowserItemSelected( file->GetDataBrowser(), item ) )
					error = file->OpenResource( item, menuCommand.commandID );
				if( error ) return eventNotHandledErr;
			}
#else
			DisplayDialog( "\pAs I haven't wired up Classic Events, no Editors work in classic mode." );
#endif
			break;
		
		case kMenuCommandRevertResource:
			break;
		
		case kMenuCommandPlaySound:
			DataBrowserItemID first, last, n;
			GetDataBrowserSelectionAnchor( file->GetDataBrowser(), &first, &last );
			for( n = first; n <= last; n++ )
			{
				ResourceObjectPtr resource = file->GetResource( n );
				if( resource->Type() == soundListRsrc )
					file->PlaySound( n );
			}
			break;
		
		default:
			return eventNotHandledErr;
	}	
	return error;
}

#endif

/*** WINDOW BOUNDS ARE CHANGING ***/
OSStatus FileWindow::BoundsChanging( EventRef event )
{
	OSStatus error = noErr;
#if TARGET_API_MAC_CARBON
	// check that window is not just being dragged
	UInt32 attributes;
	error = GetEventParameter( event, kEventParamAttributes, typeUInt32, null, sizeof(UInt32), null, &attributes );
	if( error || attributes & kWindowBoundsChangeUserDrag ) return eventNotHandledErr;
	if( g.systemVersion < kMacOSX ) return noErr;
	
	// resize window's contents
	error = eventNotHandledErr;
	if( g.systemVersion >= kMacOSX )
	{
		Rect windowBounds;
		error = GetEventParameter( event, kEventParamCurrentBounds, typeQDRectangle, null, sizeof(Rect), null, &windowBounds );
		if( error ) return eventNotHandledErr;
		SizeControl( dataBrowser, windowBounds.right - windowBounds.left, windowBounds.bottom - windowBounds.top - kDefaultHeaderHeight -1 );
	}
#else
	#pragma unused( event )
#endif
	return error;
}

/*** WINDOW BOUNDS HAVE CHANGED ***/
OSStatus FileWindow::BoundsChanged( EventRef event )
{
#if TARGET_API_MAC_CARBON
	if( event )
	{
		// check that window is not just being dragged
		UInt32 attributes;
		OSStatus error = GetEventParameter( event, kEventParamAttributes, typeUInt32, null, sizeof(UInt32), null, &attributes );
		if( error || attributes & kWindowBoundsChangeUserDrag ) return eventNotHandledErr;
	}
#else
	#pragma unused( event )
#endif
	
	GrafPtr oldPort;
	GetPort( &oldPort );
	SetPortWindowPort( window );
	
	// move everything and invalidate the area
	Rect windowBounds;
	if( g.windowMgrAvailable )	GetWindowBounds( window, kWindowContentRgn, &windowBounds );
	else						GetPortBounds( (CGrafPtr) window, &windowBounds );
	OffsetRect( &windowBounds, -windowBounds.left, -windowBounds.top );
	
#if TARGET_API_MAC_CARBON
	// resize header & data browser
	SizeControl( header, (windowBounds.right - windowBounds.left) +2, kDefaultHeaderHeight +1 );
	SizeControl( left, (windowBounds.right - windowBounds.left) /2 -4, kDefaultHeaderHeight -4 );
	SizeControl( right, (windowBounds.right - windowBounds.left) /2 -4, kDefaultHeaderHeight -4 );
	MoveControl( right, (windowBounds.right - windowBounds.left) /2, 2 );
	SizeControl( dataBrowser, windowBounds.right - windowBounds.left, windowBounds.bottom - windowBounds.top - kDefaultHeaderHeight -1 );
#else
	if( themeSavvy )
	{
		nameColumnWidth = windowBounds.right - kFileWindowAllOtherColumnWidths -6;
		if( nameColumnWidth < kFileWindowMinimumNameColumnWidth ) nameColumnWidth = kFileWindowMinimumNameColumnWidth;
		SizeControl( header, windowBounds.right +2 - windowBounds.left, kDefaultHeaderHeight +2 );
		SizeControl( sortName, nameColumnWidth, kBevelButtonHeight );
		MoveControl( sortType, (nameColumnWidth -1), kDefaultHeaderHeight +1 );
		MoveControl( sortID, (nameColumnWidth -1) + kFileWindowTypeColumnWidth, kDefaultHeaderHeight +1 );
		MoveControl( sortSize, (nameColumnWidth -1) + kFileWindowTypeColumnWidth + kFileWindowIDColumnWidth, kDefaultHeaderHeight +1 );
		MoveControl( sortAttrs, (nameColumnWidth -1) + kFileWindowTypeColumnWidth + kFileWindowIDColumnWidth + kFileWindowSizeColumnWidth, kDefaultHeaderHeight +1 );
		MoveControl( sortDir, (nameColumnWidth -1) + kFileWindowTypeColumnWidth + kFileWindowIDColumnWidth + kFileWindowSizeColumnWidth + kFileWindowAttributesColumnWidth, kDefaultHeaderHeight +1 );
	}
	MoveControl( horizScroll, -1, windowBounds.bottom - (kScrollBarWidth -1) );
	SizeControl( horizScroll, windowBounds.right - (kScrollBarWidth -3), kScrollBarWidth );
	MoveControl( vertScroll, windowBounds.right - (kScrollBarWidth -1), kFileWindowHeaderHeight );
	SizeControl( vertScroll, kScrollBarWidth, windowBounds.bottom - kFileWindowHeaderHeight - (kScrollBarWidth -2) );
	if( themeSavvy && g.systemVersion >= kMacOS85 )
	{
		SetControlViewSize( horizScroll, nameColumnWidth + kFileWindowAllOtherColumnWidths );
		SetControlViewSize( vertScroll, windowBounds.bottom - (kScrollBarWidth -1) - kFileWindowHeaderHeight );
	}
	UpdateScrollBars();
#endif
	
#if TARGET_API_MAC_CARBON
	InvalidateWindowRect( window, &windowBounds );
#else
	if( g.windowMgrAvailable )	InvalidateWindowRect( window, &windowBounds );
	else						InvalidateRect( &windowBounds );
#endif
	SetPort( oldPort );
	return noErr;
}

#if TARGET_API_MAC_CARBON

/*** WINDOW HAS BEEN ZOOMED ***/
OSStatus FileWindow::Zoomed( EventRef event )
{
	// get new bounds
	WindowRef window;
	Rect windowBounds;
	OSStatus error = GetEventParameter( event, kEventParamDirectObject, typeWindowRef, null, sizeof(WindowRef), null, &window );
	if( error ) return eventNotHandledErr;
	GetWindowBounds( window, kWindowGlobalPortRgn, &windowBounds );
	OffsetRect( &windowBounds, -windowBounds.left, -windowBounds.top );
	
	// resize controls to the window size
	SizeControl( header, windowBounds.right - windowBounds.left +2, kDefaultHeaderHeight +1 );
	SizeControl( left, (windowBounds.right - windowBounds.left) /5 *3 - windowBounds.left +4, kDefaultHeaderHeight - windowBounds.top -8 );
	MoveControl( right, (windowBounds.right - windowBounds.left) /5 *2, windowBounds.top +4 );
	SizeControl( right, windowBounds.right - ((windowBounds.right - windowBounds.left) /5 *2) -4, kDefaultHeaderHeight - windowBounds.top -8 );
	SizeControl( dataBrowser, windowBounds.right - windowBounds.left, windowBounds.bottom - windowBounds.top - kDefaultHeaderHeight -1 );
	return error;
}

/*** SET IDEAL SIZE OF WINDOW ***/
OSStatus FileWindow::SetIdealSize( EventRef event )
{
	Point idealSize;
	SetPoint( &idealSize, 512, 512 );
	OSStatus error = SetEventParameter( event, kEventParamDimensions, typeQDPoint, sizeof(Point), &idealSize );
	return error? eventNotHandledErr:noErr;
}

#endif
#if !TARGET_API_MAC_CARBON

/*** UPDATE WINDOW ***/
OSStatus FileWindow::Update( RgnHandle update )
{
	GrafPtr oldPort;
	GetPort( &oldPort );
	SetPortWindowPort( window );
	
	// get rect into which I can draw
	Rect windowBounds, rect;
	if( g.windowMgrAvailable )	GetWindowBounds( window, kWindowContentRgn, &windowBounds );
	else						GetPortBounds( (CGrafPort *) window, &windowBounds );
	SetRect( &rect, 0, 0, windowBounds.right - windowBounds.left, windowBounds.bottom - windowBounds.top );
	rect.top += kFileWindowHeaderHeight +1;
	rect.bottom -= (kScrollBarWidth -1);
	rect.right -= (kScrollBarWidth -1);
	
	// only draw resources if they are in the update region
	if( !update || RectInRgn( &windowBounds, update ) )
	{
		RgnHandle clip = NewRgn(), oldClip = NewRgn();
		RectToRegion( clip, &rect );
		GetPortClipRegion( GetWindowPort( window ), oldClip );
		SetPortClipRegion( GetWindowPort( window ), clip );
		
		SInt16 value = GetControlValue( vertScroll );
		if( themeSavvy )
		{
			// create light bg for all columns
			RGBBackColor( &g.bgColour );
			EraseRect( &rect );
			
			// add dark bg for sorted column
			Rect controlBounds;
			switch( sortOrder )
			{
				case kSortName:
					GetControlBounds( sortName, &controlBounds );
					rect.left = controlBounds.left;
					rect.right = controlBounds.right;
					break;
				
				case kSortType:
					GetControlBounds( sortType, &controlBounds );
					rect.left = controlBounds.left;
					rect.right = controlBounds.right;
					break;
				
				case kSortID:
					GetControlBounds( sortID, &controlBounds );
					rect.left = controlBounds.left;
					rect.right = controlBounds.right;
					break;
				
				case kSortSize:
					GetControlBounds( sortSize, &controlBounds );
					rect.left = controlBounds.left;
					rect.right = controlBounds.right;
					break;
				
				case kSortAttrs:
					GetControlBounds( sortAttrs, &controlBounds );
					rect.left = controlBounds.left;
					rect.right = controlBounds.right;
					break;
				
				default:
					GetControlBounds( sortAttrs, &controlBounds );
					rect.left = controlBounds.right;
					rect.right = controlBounds.right +1;
			}
			
			RGBBackColor( &g.sortColour );
			EraseRect( &rect );
		}
		else
		{
			// erase background
			RGBBackColor( &g.white );
			EraseRect( &rect );
		}
		
		// draw all resources
		ResourceObjectPtr current = resourceMap;
		for( UInt16 line = 1; line <= numResources; line++ )
		{
			// draw resource icon
			DrawResourceIcon( current, line );
			
			// reset text incase it was condensed or emboldened
			RGBForeColor( &g.black );
			TextFace( normal );
			
			// resource type
			Str255 typeStr = "\p";
			TypeToPString( current->Type(), typeStr );
			MoveTo( nameColumnWidth + kFileWindowTypeColumnOffset + kFileWindowTypeColumnWidth - StringWidth(typeStr) -5, kFileWindowHeaderHeight + (kFileWindowRowHeight * line) - (kFileWindowRowHeight - kFileWindowTextHeight)/2 - 3 - value );
			DrawString( typeStr );
			
			// resource ID
			Str255 idStr;
			NumToString( current->ID(), idStr );
			MoveTo( nameColumnWidth + kFileWindowIDColumnOffset + kFileWindowIDColumnWidth - StringWidth(idStr) -5, kFileWindowHeaderHeight + (kFileWindowRowHeight * line) - (kFileWindowRowHeight - kFileWindowTextHeight)/2 - 3 - value );
			DrawString( idStr );
			
			// resource size
			Str255 sizeStr;
			NumToString( current->Size(), sizeStr );
			MoveTo( nameColumnWidth + kFileWindowSizeColumnOffset + kFileWindowSizeColumnWidth - StringWidth(sizeStr) -5, kFileWindowHeaderHeight + (kFileWindowRowHeight * line) - (kFileWindowRowHeight - kFileWindowTextHeight)/2 - 3 - value );
			DrawString( sizeStr );
			
			// resource attribute icons
/*			Rect iconRect;
			SetRect( &iconRect, 0, 0, 16, 16 );
														OffsetRect( &iconRect, kFileWindowSizeColumnWidth + kAttrColumnOffset, (kFileLineHeight * line) +1 );
			if( current->Attributes() & resPreload)		PlotIconID( &iconRect, kAlignNone, kTransformNone, kPreloadIcon );
			else										PlotIconID( &iconRect, kAlignNone, kTransformDisabled, kPreloadIcon );
														OffsetRect( &iconRect, kAttrIconSep, 0 );
			if( current->Attributes() & resProtected)	PlotIconID( &iconRect, kAlignNone, kTransformNone, kProtectedIcon );
			else										PlotIconID( &iconRect, kAlignNone, kTransformDisabled, kProtectedIcon );
														OffsetRect( &iconRect, kAttrIconSep, 0 );
			if( current->Attributes() & resLocked)		PlotIconID( &iconRect, kAlignNone, kTransformNone, kLockedIcon );
			else										PlotIconID( &iconRect, kAlignNone, kTransformDisabled, kLockedIcon );
														OffsetRect( &iconRect, kAttrIconSep, 0 );
			if( current->Attributes() & resPurgeable)	PlotIconID( &iconRect, kAlignNone, kTransformNone, kPurgableIcon );
			else										PlotIconID( &iconRect, kAlignNone, kTransformDisabled, kPurgableIcon );
														OffsetRect( &iconRect, kAttrIconSep, 0 );
			if( current->Attributes() & resSysHeap)		PlotIconID( &iconRect, kAlignNone, kTransformNone, kSysHeapIcon );
			else										PlotIconID( &iconRect, kAlignNone, kTransformDisabled, kSysHeapIcon );
														OffsetRect( &iconRect, kAttrIconSep, 0 );
			if( current->Attributes() & null)			PlotIconID( &iconRect, kAlignNone, kTransformNone, kCompressedIcon );
			else										PlotIconID( &iconRect, kAlignNone, kTransformDisabled, kCompressedIcon );
*/			
		/*	resSysHeap		= 64,	// System or application heap?
			resPurgeable	= 32,	// Purgeable resource?
			resLocked		= 16,	// Load it in locked?
			resProtected	= 8,	// Protected?
			resPreload		= 4,	// Load in on OpenResFile?
			resChanged		= 2,	// Resource changed? - not used by ResKnife			*/
			
			if( themeSavvy )
			{
				// draw divider line
				MoveTo( 0, kFileWindowHeaderHeight + (kFileWindowRowHeight * line) - value );
				RGBForeColor( &g.white );
				Line( windowBounds.right - windowBounds.left -1, 0 );
			}
			
			// move on
			current = current->Next();
		}
		
		SetPortClipRegion( GetWindowPort( window ), oldClip );
		DisposeRgn( clip );
		DisposeRgn( oldClip );
	}
	
	// update the controls
	if( !themeSavvy ) DrawGrowIcon( window );
	UpdateControls( window, update );
	SetPort( oldPort );
	return noErr;
}

/*** ACTIVATE WINDOW ***/
OSStatus FileWindow::Activate( Boolean active )
{
	// invalidate the whole window
	GrafPtr oldPort;
	GetPort( &oldPort );
	SetPortWindowPort( window );
	
	Rect windowBounds;
	if( g.windowMgrAvailable )	GetWindowBounds( window, kWindowContentRgn, &windowBounds );
	else						GetPortBounds( (CGrafPort *) window, &windowBounds );
	if( g.windowMgrAvailable )	InvalidateWindowRect( window, &windowBounds );
	else						InvalidateRect( &windowBounds );
	SetPort( oldPort );
	
	// set the controls to display correctly
	ControlPartCode hiliteState = active? kControlNoPart:kControlInactivePart;
	if( themeSavvy )
	{
		HiliteControl( header, hiliteState );
		HiliteControl( sortName, hiliteState );
		HiliteControl( sortType, hiliteState );
		HiliteControl( sortID, hiliteState );
		HiliteControl( sortSize, hiliteState );
		HiliteControl( sortAttrs, hiliteState );
		HiliteControl( sortDir, hiliteState );
	}
		HiliteControl( horizScroll, hiliteState );
		HiliteControl( vertScroll, hiliteState );
	return noErr;
}

/*** MOUSE CLICK ***/
OSStatus FileWindow::Click( Point globalMouse, EventModifiers modifiers )
{
	// set the mouse location to local co-ords
	GrafPtr oldPort;
	GetPort( &oldPort );
	SetPortWindowPort( window );
	Point localMouse = globalMouse, windowLoc = {0,0};
	GlobalToLocal( &localMouse );
	LocalToGlobal( &windowLoc );
	SetPort( oldPort );
	
	// handle a click on a control first
	ControlHandle control;
	SInt16 controlPart;
	if( themeSavvy )	control = FindControlUnderMouse( localMouse, window, &controlPart );
	else				controlPart = FindControl( localMouse, window, &control );
	if( control && controlPart != kControlNoPart )
	{
		// scroll the windoow
		if( themeSavvy )
		{
			ControlActionUPP scrollAction = NewControlActionUPP( FileWindowScrollAction );
			controlPart = HandleControlClick( control, localMouse, modifiers, scrollAction );
			DisposeControlActionUPP( scrollAction );
		}
		else if( controlPart != kControlIndicatorPart )
		{
			ControlActionUPP scrollAction = NewControlActionUPP( FileWindowScrollAction );
			TrackControl( control, localMouse, scrollAction );
			DisposeControlActionUPP( scrollAction );
		}
		else	// clicks in the thumb cause crashes if given a ControlActionUPP
		{
			controlPart = TrackControl( control, localMouse, nil );
			Update();
		}
		
		// save new offset & return
		UpdateScrollBars();
		return noErr;
	}
	else
	{
		// click was not on a controlÉ
		ResourceObjectPtr resource = resourceMap;
		static unsigned long clickTime;
		
		// check shift key status
		Boolean	shiftKeyDown = false,
				optionKeyDown = false;
		
		KeyMap	theKeys;
		GetKeys( theKeys );
		if( theKeys[1] & (shiftKey >> shiftKeyBit) )	shiftKeyDown = true;
		if( theKeys[1] & (optionKey >> shiftKeyBit) )	optionKeyDown = true;
		
		// clicked on a part of the window where no resource is listed
		SInt16 newSelection = ( localMouse.v + GetControlValue(vertScroll) - kFileWindowHeaderHeight ) / kFileWindowRowHeight +1;
		if( newSelection > numResources )
		{
			ClearSelection();	// should go to drag selection instead
			Update();
			return noErr;
		}
		
		// cycle to clicked resource
		for( newSelection; newSelection > 1; newSelection-- )
			resource = resource->Next();
		
		// check for click on attributes
/*		if( mouse.h >= g.nameColumnWidth + kAttrColumnOffset )			// clicked on attribute
		{
			short attrClicked = mouse.h;
			attrClicked -= g.nameColumnWidth + kAttrColumnOffset;
			attrClicked /= kAttrIconSep;
			attrClicked += resPreloadBit;
			if( (r.attrs >> attrClicked) & 0x01 )	r.attrs -= 1 << attrClicked;
			else									r.attrs += 1 << attrClicked;
			
			// mark file & resource for saving
			dirty = true;
			r.dirty = true;
			ChangedResource( r.resource );
			
			// update the window
			Update();
		}
		
		// if in nameIconRgn, must be a click on a resource
		else*/ if( PtInRgn( localMouse, resource->nameIconRgn ) )
		{
			if( resource->Selected() == false )
			{
				if( shiftKeyDown )									// shift click on unselected
				{
					resource->Select( true );
					numSelected += 1;
				}
				else												// click on unselected
				{
					clickTime = TickCount();
					ClearSelection();
					resource->Select( true );
					numSelected = 1;
				}
			}
			else
			{
				if( TickCount() <= clickTime + GetDblTime() )		// double click
				{
					ClearSelection();
					resource->Select( true );
					numSelected = 1;
					OpenResource( resource->Number(), optionKeyDown? kMenuCommandOpenHex:kMenuCommandOpenDefault );
				}
				else if( shiftKeyDown )								// shift click on selected
				{
					resource->Select( false );
					numSelected -= 1;
				}
				else												// click on selected
				{
					clickTime = TickCount();
					resource->Select( true );
				}
			}
			
			// update the window
			Update();
			
			// check for resource drags
			if( WaitMouseMoved( globalMouse ) )			// drag activated
			{
				OSErr error = noErr;
				DragReference theDragRef;
				ItemReference theItemRef = 1;
				FlavorFlags theFlags = flavorNotSaved;
				DragSendDataUPP sendProc = null;		// bug: NewDragSendDataProc( SendFileDataProc );
				
				// setup imaginary file
				PromiseHFSFlavor	theFile;
				theFile.fileType	= kResourceTransferType;
				theFile.fileCreator	= kResKnifeCreator;
				theFile.fdFlags		= null;				// finder flags
				theFile.promisedFlavor = kResourceTransferType;
				
				// create the drag reference
				NewDrag( &theDragRef );
				error = MemError();
				if( error ) return error;
				SetDragSendProc( theDragRef, sendProc, this );
				
				RgnHandle	dragRgn = NewRgn(),
							subtractRgn = NewRgn();
				
				// get region of dragged items, using translucent dragging where possible
				GWorldPtr imageGWorld = null;
				
				resource = resourceMap;
				while( resource )
				{
					if( resource->Selected() )
						UnionRgn( resource->nameIconRgn, dragRgn, dragRgn );	// add new region to rest of drag region
					resource = resource->Next();
				}
				
/*				if( g.translucentDrag )
				{
					Point dragOffset;
					DataBrowserItemID resCounter = 0;
					SetPt( &dragOffset, 0, kFileWindowHeaderHeight );
					resource = resourceMap;
					
					while( !resource->Selected() )
					{
						resCounter++;
						resource = resource->Next();
					}
					
					error = CreateDragImage( resource, &imageGWorld );
					if( !error )
					{
						// init mask region
						RgnHandle maskRgn = NewRgn();
						CopyRgn( resource->nameIconRgn, maskRgn );
						OffsetRgn( maskRgn, 0, -kFileWindowRowHeight * resCounter );
						
						// init rects
						Rect sourceRect, destRect;
						SetRect( &sourceRect, 0, 0, nameColumnWidth, kFileWindowRowHeight );
						SetRect( &destRect, 0, 0, nameColumnWidth, kFileWindowRowHeight );
						OffsetRect( &destRect, 0, kFileWindowHeaderHeight );
						
						// init GWorld
						PixMapHandle imagePixMap = GetGWorldPixMap( imageGWorld );
						DragImageFlags imageFlags = kDragStandardTranslucency | kDragRegionAndImage;
						error = SetDragImage( theDragRef, imagePixMap, maskRgn, dragOffset, imageFlags );
						CopyBits( &GrafPtr( imageGWorld )->portBits, &GrafPtr( window )->portBits, &sourceRect, &destRect, srcCopy, maskRgn );
						if( error ) SysBeep(0);
						DisposeGWorld( imageGWorld );
						DisposeRgn( maskRgn );
					}
				}
*/				
				// subtract middles from icons
				CopyRgn( dragRgn, subtractRgn );					// duplicate region
				InsetRgn( subtractRgn, 2, 2 );						// inset it by 2 pixels
				DiffRgn( dragRgn, subtractRgn, dragRgn );			// subtract subRgn from addRgn, save in nameIconRgn
				OffsetRgn( dragRgn, windowLoc.h, windowLoc.v );		// change drag region to global coords
				
				// add flavour data to drag
				error = AddDragItemFlavor( theDragRef, theItemRef, flavorTypePromiseHFS, &theFile, sizeof(PromiseHFSFlavor), theFlags );
				error = AddDragItemFlavor( theDragRef, theItemRef, kResourceTransferType, null, 0, theFlags );
				
				// track the drag, then clean up
				EventRecord event;
				event.what = mouseDown;
				event.message = null;
				event.when = TickCount();
				event.where = globalMouse;
				event.modifiers = modifiers;

				error = TrackDrag( theDragRef, &event, dragRgn );
				if( theDragRef )	DisposeDrag( theDragRef );
				if( subtractRgn )	DisposeRgn( subtractRgn );
				if( dragRgn )		DisposeRgn( dragRgn );
			}
		}
		
		// otherwise, must be a drag selection or de-selection
		else
		{
			// clear current selections
			if( shiftKeyDown == false )
			{
				ClearSelection();
				Update();
			}
			
			// check for resource drags
			if( WaitMouseMoved( globalMouse ) )
			{
				// set pen
				PenState oldState, dragState;
				GetPenState( &oldState );
				PenSize( 2, 2 );
				PenPat( &qd.gray );
				PenMode( srcXor );
				GetPenState( &dragState );
				SetPenState( &oldState );
				
				// do drag selection
				
//				RgnHandle oldClip = NewRgn();
//				GetClip( oldClip );
//				SetClip( bodyRgn );
				
				Point mouse, savedMouse = globalMouse, oldMouse = globalMouse;
				Rect dragRect = {0,0,0,0};
				while( WaitMouseUp() )
				{
					GetMouse( &mouse );
					SetPortWindowPort( window );
					if( mouse.h != oldMouse.h || mouse.v != oldMouse.v )
					{
						SetPenState( &dragState );
						FrameRect( &dragRect );
						SetRect( &dragRect,	(savedMouse.h < mouse.h)? savedMouse.h : mouse.h,
											(savedMouse.v < mouse.v)? savedMouse.v : mouse.v,
											(savedMouse.h > mouse.h)? savedMouse.h : mouse.h,
											(savedMouse.v > mouse.v)? savedMouse.v : mouse.v );
						OffsetRect( &dragRect, -windowLoc.h, -windowLoc.v );
						FrameRect( &dragRect );
						SetPenState( &oldState );
						
						// check to see if selection region coincides with resources
						short i;
						RgnHandle dragRgn = NewRgn(), resultRgn = NewRgn();
						RectRgn( dragRgn, &dragRect );
						ResourceObjectPtr resource = resourceMap;
						for( i = 1; i <= GetControlValue(vertScroll); i++ )
							resource = resource->Next();									// move to first res in window
						for( i = GetControlValue(vertScroll); i < numResources - GetControlValue(vertScroll); i++ )
						{
							SetEmptyRgn( resultRgn );
							SectRgn( dragRgn, resource->nameIconRgn, resultRgn );
							resource->Select( !EmptyRgn( resultRgn ) );
							DrawResourceIcon( resource, i+1 );
							resource = resource->Next();
						}
						DisposeRgn( resultRgn );
						DisposeRgn( dragRgn );
					}
					SetPort( oldPort );
					oldMouse = mouse;
				}
				
				// restore clip region
//				SetClip( oldClip );
			}
			
			// update the window
			Update();
		}
		return eventNotHandledErr;
	}
}

/*** FILE WINDOW SCROLL ACTION ***/
pascal void FileWindowScrollAction( ControlHandle control, SInt16 controlPart )
{
	// get owning window
	if( !controlPart ) return;
	SInt8 state = HGetState( (Handle) control );
	HLock( (Handle) control );
	WindowRef window = GetControlOwner( control );
	HSetState( (Handle) control, state );
	WindowObjectPtr winObj = (WindowObjectPtr) GetWindowRefCon( window );
	
	// get window bounds
	Rect windowBounds;
	if( g.windowMgrAvailable )	GetWindowBounds( window, kWindowContentRgn, &windowBounds );
	else						GetPortBounds( (CGrafPort *) window, &windowBounds );
	windowBounds.top += kFileWindowHeaderHeight +1;
	windowBounds.bottom -= (kScrollBarWidth -1);
	windowBounds.right -= (kScrollBarWidth -1);
	UInt16 windowHeight = windowBounds.bottom - windowBounds.top;

	// decide how many pixels to scroll (and in which direction)
	SInt16 delta = 0;
	switch( controlPart )
	{
		case kControlUpButtonPart:		// up (20)
			delta = -kFileWindowRowHeight;
		  	break;
			
		case kControlDownButtonPart:	// down (21)
			delta =  kFileWindowRowHeight;
		  	break;
			
		case kControlPageUpPart:		// page up (22)
			delta = kFileWindowRowHeight - windowHeight;
		  	break;
			
		case kControlPageDownPart:		// page down (23)
			delta = windowHeight - kFileWindowRowHeight;
		  	break;
	}

	// calculate and correct control value
	SInt16 max			= GetControlMaximum( control );
	SInt16 startValue	= GetControlValue( control );
	SInt16 endValue		= startValue + delta;
	if( endValue < 0 )		endValue = 0;
	if( endValue > max )	endValue = max;
	
	// only update window if anything changed
	if( endValue != startValue || controlPart == kControlIndicatorPart )
	{
		SetControlValue( control, endValue );
		winObj->Update();
	}
}

#endif

/*** NEW RESOURCE SHEET WINDOW EVENT HANDLER ***/
pascal OSStatus NewResourceEventHandler( EventHandlerCallRef callRef, EventRef event, void *userData )
{
	#pragma unused( callRef, userData )
	// get control that was hit
	UInt32 command;
	ControlRef control;
	GetEventParameter( event, kEventParamDirectObject, typeControlRef, null, sizeof(ControlRef), null, &control );
	GetControlCommandID( control, &command );
	
	// get parent window (so resource is added to correct file)
	WindowRef parent;
	WindowRef sheet = GetControlOwner( control );
	GetSheetWindowParent( sheet, &parent );
	FileWindowPtr file = (FileWindowPtr) GetWindowRefCon( parent );
		
	// do the button action
	switch( command )
	{
		case kHICommandOK:
		{	// close the sheet
			HideSheetWindow( sheet );
			DisposeWindow( sheet );
			
			// extract all the info about the resource we need
			Str255	name = "\pTest Resource Beta";
			ResType	type = 'test';
			SInt16	resID = 129;
			SInt16	attribs = 0;
			file->CreateNewResource( name, type, resID, attribs );
		}	break;
		
		case kHICommandCancel:
			// close the sheet
			HideSheetWindow( sheet );
			DisposeWindow( sheet );
			break;
		
		default:
			DebugError( "\pCommand assigned to that control was not dealt with." );
	}
	return noErr;
}

  /********************************/
 /* FILE WINDOW DRAWING ROUTINES */
/********************************/

#if !TARGET_API_MAC_CARBON

/*** UPDATE SCROLL BARS ***/
OSStatus FileWindow::UpdateScrollBars( void )
{
	// get rect into which I can draw
	Rect windowBounds;
	if( g.windowMgrAvailable )	GetWindowBounds( window, kWindowContentRgn, &windowBounds );
	else						GetPortBounds( (CGrafPort *) window, &windowBounds );
	windowBounds.top += kFileWindowHeaderHeight +1;
	windowBounds.bottom -= (kScrollBarWidth -1);
	windowBounds.right -= (kScrollBarWidth -1);
	UInt16 windowHeight = windowBounds.bottom - windowBounds.top;
	
	// horizontal scroll bar
	if( nameColumnWidth + kFileWindowAllOtherColumnWidths - windowBounds.right <= 0 )
		SetControlMaximum( horizScroll, 0 );
	else SetControlMaximum( horizScroll, nameColumnWidth + kFileWindowAllOtherColumnWidths - windowBounds.right );
	
	// vertical scroll bar
	SInt16 value = GetControlValue( vertScroll );
	if( windowHeight > numResources * kFileWindowRowHeight - value )
		SetControlMaximum( vertScroll, value );
	else SetControlMaximum( vertScroll, numResources * kFileWindowRowHeight - windowHeight );
	return noErr;
}

/*** DRAW RESOURCE ICON ***/
OSStatus FileWindow::DrawResourceIcon( ResourceObjectPtr resource, UInt16 line )
{
	OSStatus			error = noErr;
	Rect				nameRect, iconRect;
	Str255				nameStr;
	IconAlignmentType	alignment;
	IconTransformType	transformation;
	SInt16 value = GetControlValue( vertScroll );
	
	// resource icon
	alignment = kAlignNone;
	if( resource->Selected() )	transformation = kTransformSelected;
	else						transformation = kTransformNone;
	SetRect( &iconRect, 0, 0, 16, 16 );
	OffsetRect( &iconRect, kFileWindowNameColumnTextOffset -20, kFileWindowHeaderHeight + (kFileWindowRowHeight * line) - (kFileWindowRowHeight/2) - 8 - value );
	
	IconSuiteRef iconSuite;
	GetIconSuite( &iconSuite, kDefaultResourceIcon, kSelectorAllSmallData );
	error = PlotIconSuite( &iconRect, alignment, transformation, iconSuite );
	if( error ) return error;
	
/*	IconSelectorValue whichIcons = kSelectorSmall32Bit | kSelectorSmall8BitMask;
	IconFamilyHandle iconFamily;
	IconSuiteRef iconSuite;
	
	iconFamily = (IconFamilyHandle) Get1Resource( kIconFamilyType, kDefaultResourceIcon );
	IconFamilyToIconSuite( iconFamily, whichIcons, &iconSuite );
	PlotIconSuite( &iconRect, alignment, transformation, iconSuite );
	DisposeIconSuite( iconSuite, false );
	ReleaseResource( (Handle) iconFamily );
*/	
	// get name
	if( *resource->Name() != 0x00 )
	{
		CopyPString( resource->name, nameStr );
	}
	else
	{
		Str255 unnamedStr;
		if( resource->dataFork ) GetIndString( unnamedStr, kResourceNameStrings, kStringDataFork );
		else if( resource->ID() == -16455 && (resource->Type() == 'icns' || resource->Type() == 'icl8' || resource->Type() == 'icl4' || resource->Type() == 'ICN#' || resource->Type() == 'ics8' || resource->Type() == 'ics4' || resource->Type() == 'ics#') )
			GetIndString( unnamedStr, kResourceNameStrings, kStringCustomIcon );
		else GetIndString( unnamedStr, kResourceNameStrings, kStringUntitledResource );
		CopyPString( unnamedStr, nameStr );
	}
	
	// condense & italicise if necessary
	if( StringWidth( nameStr ) > nameColumnWidth - 45 )
	{
		if( resource->Dirty() )	TextFace( condense | bold );
		else					TextFace( condense );
	}
	else
	{
		if( resource->Dirty() )	TextFace( bold );
		else					TextFace( normal );
	}
	
	// add ellipsis if necessary
	while( StringWidth( nameStr ) > nameColumnWidth - kFileWindowNameColumnTextOffset -3 )
	{
		nameStr[0] -= 1;				// shorten string
		nameStr[ nameStr[0] ] = 0xC9;	// replace new last char with 'É'
	}
	
	// set text/box colour
	if( *resource->Name() == 0x00 )
			RGBForeColor( &g.frameColour );
	else	RGBForeColor( &g.black );
	
	// draw hilight box if selected
	if( resource->Selected() )
	{
		SetRect( &nameRect, 0, 0, StringWidth( nameStr ) +4, kFileWindowTextHeight );
		OffsetRect( &nameRect, kFileWindowNameColumnTextOffset -2, kFileWindowHeaderHeight + (kFileWindowRowHeight * line) - (kFileWindowRowHeight - kFileWindowTextHeight)/2 - kFileWindowTextHeight - value );
		PaintRect( &nameRect );
		RGBForeColor( &g.white );	// set text colour to white
	}
	
	// draw name in set colour
	SInt16 font;
	GetFNum( "\pGeneva", &font );
	TextFont( font );
	TextSize( 10 );
//	TextFont( kControlFontSmallSystemFont );	// doesn't give right effect
	MoveTo( kFileWindowNameColumnTextOffset, kFileWindowHeaderHeight + (kFileWindowRowHeight * line) - (kFileWindowRowHeight - kFileWindowTextHeight)/2 - 3 - value );
	DrawString( nameStr );
	RGBForeColor( &g.black );
		
	// create name & icon region for click detection and dragging
	RgnHandle addRgn = NewRgn();
	if( !addRgn )
	{
		DisposeIconSuite( iconSuite, true );
		return memFullErr;
	}
	
	if( resource->nameIconRgn )
		DisposeRgn( resource->nameIconRgn );
	resource->nameIconRgn = NewRgn();
	if( !resource->nameIconRgn )
	{
		DisposeRgn( addRgn );
		DisposeIconSuite( iconSuite, true );
		return memFullErr;
	}
	
		// resource icon
	SetRect( &iconRect, 0, 0, 16, 16 );
	OffsetRect( &iconRect, 22, kFileWindowHeaderHeight + (kFileWindowRowHeight * (line-1)) +2 );
	IconSuiteToRgn( resource->nameIconRgn, &iconRect, kAlignNone, iconSuite );
	
		// resource name					
	SetRect( &nameRect, 0, 0, StringWidth( nameStr ) +4, kFileWindowTextHeight );
	OffsetRect( &nameRect, 40, kFileWindowHeaderHeight + (kFileWindowRowHeight * (line-1)) +3 );
	RectRgn( addRgn, &nameRect );										// convert textRect to region
	UnionRgn( addRgn, resource->nameIconRgn, resource->nameIconRgn );	// add new region to icon region
	DisposeRgn( addRgn );
	DisposeIconSuite( iconSuite, true );
	return error;
}

#endif

  /*****************************/
 /* RESOURCE MAP MANIPULATION */
/*****************************/

/*** DISPLAY NEW RESOURCE SHEET ***/
OSStatus FileWindow::DisplayNewResourceSheet( void )
{
#if TARGET_API_MAC_CARBON
	// create a nib reference (only searches the application bundle)
	IBNibRef nibRef = null;
	OSStatus error = CreateNibReference( CFSTR("ResKnife"), &nibRef );
	if( error != noErr )
	{
		DisplayError( "\pThe nib file reference could not be obtained." );
		return error;
	}
	
	// create save sheet
	WindowRef sheet;
	error = CreateWindowFromNib( nibRef, CFSTR("New Resource"), &sheet );
	if( error != noErr )
	{
		DisplayError( "\pA sheet window could not be obtained from the nib file." );
		return error;
	}
	
	// dispose of nib ref
	DisposeNibReference( nibRef );
	
	// install window event handler
	EventTypeSpec events = { kEventClassControl, kEventControlHit };
	EventHandlerUPP eventHandler = NewEventHandlerUPP( NewResourceEventHandler );
	InstallWindowEventHandler( sheet, eventHandler, 1, &events, 0, null );
	
	// show sheet window
	ShowSheetWindow( sheet, window );
	return error;
#else
	return eventNotHandledErr;
#endif
}

/*** DISPLAY NEW RESOURCE DIALOG ***/
OSStatus FileWindow::DisplayNewResourceDialog( void )
{
	// create and show dialog
	OSStatus error = noErr;
	GrafPtr oldPort;
	DialogRef dialog = GetNewDialog( kNewResourceDialog, null, kFirstWindowOfClass );
	SetDialogDefaultItem( dialog, ok );
	GetPort( &oldPort );
	SetPortWindowPort( GetDialogWindow(dialog) );
	ShowWindow( GetDialogWindow(dialog) );
	
	// set up variables
	Str255 name		= "\pTest Resource Alpha";
	ResType type	= 'test';
	SInt16 resID	= 128;
	SInt16 attributes = 0x0000;
	
	// handle dialog events
	Rect			box;
	Handle			item;
	short			itemHit;
	DialogItemType	itemType;
	do
	{
		ModalDialog( null, &itemHit );
		GetDialogItem( dialog, itemHit, &itemType, &item, &box );
		switch( itemHit )
		{
			case 5:
			{	Str255 popupText;
				MenuRef popupMenu = GetMenu( 140 );
				SInt16 popupItem = GetControlValue( (ControlRef) item );
				GetMenuItemText( popupMenu, popupItem, popupText );
				GetDialogItem( dialog, 4, &itemType, &item, &box );
				SetDialogItemText( item, popupText );
				if( popupItem == 1 )	SelectDialogItemText( dialog, 4, 0x0000, 0x0000 );
				else					SelectDialogItemText( dialog, 4, 0x0000, 0xFFFF );
				RgnHandle updateRgn = NewRgn();
				RectRgn( updateRgn, &box );
				UpdateDialog( dialog, updateRgn );
				DisposeRgn( updateRgn );
				DisposeMenu( popupMenu );
			}	break;
			
			case 7:
			case 8:
			case 9:
			case 10:
			case 11:
			{	attributes ^= 1 << (itemHit -5);
				SetControlValue( (ControlRef) item, (short) (attributes & 1 << (itemHit -5)) );
			}	break;
		}
	}	while( itemHit != ok && itemHit != cancel );
	
	HideWindow( GetDialogWindow(dialog) );
	if( itemHit == cancel )
	{
		DisposeDialog( dialog );
		SetPort( oldPort );
		return userCanceledErr;
	}
	else
	{
		
		// get resource name
		GetDialogItem( dialog, 3, &itemType, &item, &box );
		GetDialogItemText( item, name );
		
		// get resource type
		Str255 string;
		GetDialogItem( dialog, 4, &itemType, &item, &box );
		GetDialogItemText( item, string );
		if( *string != sizeof(ResType) )
		{
			DisplayError( "\pInvalid resource type given", "\pYou should either choose a type from the pop-up menu, or enter a four character resource type of your own." );
			SetPort( oldPort );
			DisposeDialog( dialog );
			return paramErr;
		}
		BlockMoveData( string +1, &type, sizeof(ResType) );
		
		// get resource ID
		long number;
		GetDialogItem( dialog, 6, &itemType, &item, &box );
		GetDialogItemText( item, string );
		StringToNum( string, &number );
		if( number < -32768 || number > 32767 )
		{
			DisplayError( "\pInvalid resource ID chosen", "\pYou have to pick a number between -32768 and +32767. All ID numbers less than 128 are reserved by Apple." );
			SetPort( oldPort );
			DisposeDialog( dialog );
			return paramErr;
		}
		resID = (short) number;
		
		// create resource
		error = CreateNewResource( name, type, resID, attributes );
	}
	SetPort( oldPort );
	DisposeDialog( dialog );
	return error;
}

/*** CREATE NEW RESOURCE ***/
OSStatus FileWindow::CreateNewResource( ConstStr255Param name, ResType type, SInt16 resID, SInt16 attributes )
{
	// cycle through ResourceObject chain
	OSStatus error = noErr;
	ResourceObjectPtr last = resourceMap, addition = (ResourceObjectPtr) NewPtrClear( sizeof(ResourceObject) );
	while( last->next )	last = last->next;
	
	// append new resource to chain
	last->next = addition;
	addition->file = this;
	addition->number = last->number + 1;
	addition->data = NewHandleClear( 0 );
	BlockMoveData( name, addition->name, sizeof(Str255) );
	addition->size = 0;
	addition->type = type;
	addition->resID = resID;
	addition->attribs = attributes;
	
	// update the file's resource counts
	numResources += 1;
	if( GetResourceCount(type) == 0 )
		numTypes += 1;
	
#if TARGET_API_MAC_CARBON
	// add the resource to the databrowser
	error = AddDataBrowserItems( dataBrowser, kDataBrowserNoItem, 1, &addition->number, kDataBrowserItemNoProperty );
#endif
	
	// mark file as dirty
	fileDirty = true;
	SetWindowModified( window, fileDirty );
	
	return error;
}

/*** OPEN RESOURCE ***/
OSStatus FileWindow::OpenResource( DataBrowserItemID itemID, MenuCommand command )
{
	#pragma unused( command )
	// get opened resource
	OSStatus error = noErr;
	Boolean stop = false;
	ResourceObjectPtr resource = GetResource( itemID );
	
	// check for null resource
	if( resource == null ) 
	{
		DisplayError( "\pYou just double-clicked on a non-existant resource!" );
		return paramErr;
	}
	
	// open correct editor
	switch( command )
	{
		case kMenuCommandOpenHex:
			LoadEditor( resource, "\pHex Editor" );
			break;
		
		case kMenuCommandOpenDefault:
			Str255 typeStr;
			TypeToPString( resource->Type(), typeStr );
			AppendPString( typeStr, "\p Editor" );
			LoadEditor( resource, typeStr );
			break;
		
		case kMenuCommandOpenTemplate:
			LoadEditor( resource, "\pTemplate Editor" );
			error = eventNotHandledErr;
			break;
		
		case kMenuCommandOpenSpecific:
			// bug: display template selection dialog here
			error = eventNotHandledErr;
			break;
		
		default:
			DebugError( "\pWrong command sent to FileWindow::OpenResource()" );
			error = eventNotHandledErr;
			break;
	}
	return error;
}

/*** DISPOSE RESOURCE MAP ***/
OSStatus FileWindow::DisposeResourceMap()
{
	if( !resourceMap )	return noErr;	// resource map already disposed
	
	UInt32 numDeleted = 0;
	ResourceObjectPtr current = resourceMap, next;
	while( current )
	{
		next = current->Next();
		if( current->nameIconRgn )	DisposeRgn( current->nameIconRgn );
		if( current->data )			DisposeHandle( current->data );
		DisposePtr( (Ptr) current );
//		delete current;
		numDeleted += 1;
		current = next;
	}
	if( numResources != numDeleted )	return paramErr;	// my lazy way of saying I don't know what happened
	else								return noErr;
}

  /******************/
 /* SOUND ROUTINES */
/******************/

/*** PLAY SOUND ***/
OSStatus FileWindow::PlaySound( DataBrowserItemID itemID )
{
	long refNum = 0;	// unused
	ResourceObjectPtr resource = GetResource( itemID );
	if( resource->Data() )
	{
		SInt8 state = HGetState( resource->Data() );
		HLock( resource->Data() );
		if( g.asyncSound )	SHPlayByHandle( resource->Data(), &refNum );
		else				SndPlay( nil, (SndListHandle) resource->Data(), false );
		HSetState( resource->Data(), state );
	}
	return noErr;
}

  /*******************************/
 /* VARIABLE ACCESSOR FUNCTIONS */
/*******************************/

/*** GET FILE SPEC ***/
FSSpecPtr FileWindow::GetFileSpec( void )
{
	return fileSpec;
}

/*** SET FILE SPEC ***/
void FileWindow::SetFileSpec( FSSpecPtr spec )
{
	fileExists = spec? true:false;
	if( fileExists )
	{
		BlockMoveData( (Ptr) spec, (Ptr) fileSpec, sizeof(FSSpec) );
		SetWindowProxyFSSpec( window, fileSpec );
		SetWindowModified( window, fileDirty );
	}
	else
	{
		DisposePtr( (Ptr) fileSpec );
		fileSpec = (FSSpecPtr) NewPtrClear( sizeof(FSSpec) );
		SetWindowProxyCreatorAndType( window, kResKnifeCreator, kResourceFileType, kOnSystemDisk );
		SetWindowModified( window, true );
	}
}

/*** IS FILE DIRTY ***/
Boolean FileWindow::IsFileDirty( void )
{
	return fileDirty;
}

/*** SET FILE DIRTY ***/
void FileWindow::SetFileDirty( Boolean dirty )
{
	fileDirty = dirty;	// bug: used to crash my machine but mysteriously doesn't any more
	SetWindowModified( window, dirty );
}

#if TARGET_API_MAC_CARBON

/*** GET DATA BROWSER ***/
ControlRef FileWindow::GetDataBrowser( void )
{
	return dataBrowser;
}

#endif

  /**********************/
 /* RESOURCE ACCESSORS */
/**********************/

/*** GET RESOURCE COUNT ***/
UInt32 FileWindow::GetResourceCount( ResType wanted )
{
	#pragma unused( wanted )
	return numResources;
}

/*** GET RESOURCE ***/
ResourceObjectPtr FileWindow::GetResource( DataBrowserItemID itemID )
{
	ResourceObjectPtr res = resourceMap;
	if( itemID == kDataBrowserNoItem ) return null;
	while( itemID != res->Number() )
	{
		res = res->Next();
		if( res == null ) return null;
	}
	return res;
}

/*** GET RESOURCE NAME ***/
UInt8* FileWindow::GetResourceName( DataBrowserItemID itemID )
{
	ResourceObjectPtr resource = GetResource( itemID );
	if( resource == null ) return null;
	return resource->Name();
}

/*** GET RESOURCE SIZE ***/
UInt32 FileWindow::GetResourceSize( DataBrowserItemID itemID )
{
	ResourceObjectPtr resource = GetResource( itemID );
	if( resource == null ) return null;
	return resource->Size();
}

/*** GET RESOURCE TYPE ***/
ResType	FileWindow::GetResourceType( DataBrowserItemID itemID )
{
	ResourceObjectPtr resource = GetResource( itemID );
	if( resource == null ) return null;
	return resource->Type();
}

/*** GET RESOURCE ID ***/
SInt16	FileWindow::GetResourceID( DataBrowserItemID itemID )
{
	ResourceObjectPtr resource = GetResource( itemID );
	if( resource == null ) return null;
	return resource->ID();
}

/*** GET RESOURCE ATTRIBUTES ***/
SInt16	FileWindow::GetResourceAttributes( DataBrowserItemID itemID )
{
	ResourceObjectPtr resource = GetResource( itemID );
	if( resource == null ) return null;
	return resource->Attributes();
}