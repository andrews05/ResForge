#include "Events.h"
#include "HexWindow.h"
#include "Utility.h"

extern globals g;
extern prefs p;

  /******************/
 /* EVENT HANDLING */
/******************/

/*** CARBON WINDOW EVENT HANDLER ***/
pascal OSStatus CarbonWindowEventHandler( EventHandlerCallRef handler, EventRef event, void *userData )
{
	#pragma unused( handler )
	OSStatus		error = eventNotHandledErr;
	Plug_PlugInRef	plugRef = (Plug_PlugInRef) userData;
	WindowRef		window = GetUserFocusWindow();
	
	// get event type
	UInt32 eventClass = GetEventClass( event );
	UInt32 eventKind = GetEventKind( event );
	
	// get event parameters
	if( eventClass == kEventClassWindow )
		GetEventParameter( event, kEventParamDirectObject, typeWindowRef, null, sizeof(WindowRef), null, &window );
	if( !window ) return error;
	Plug_WindowRef plugWindow = Host_GetPlugWindowFromWindowRef( window );
	if( !plugWindow ) return error;
	HexWindowPtr hexWindow = (HexWindowPtr) Host_GetWindowRefCon( plugWindow );
	if( !hexWindow ) return error;
	
	// get window rect
	Rect windowBounds;
	GetWindowPortBounds( window, &windowBounds );
	
	// handle event
	static EventHandlerRef resizeEventHandlerRef = null;
	switch( eventClass )
	{
		case kEventClassWindow:
			switch( eventKind )
			{
				case kEventWindowClose:
					delete hexWindow;
					break;
				
				case kEventWindowActivated:
				case kEventWindowDeactivated:
					if( hexWindow->activeWindow && hexWindow->insertionPointVisable )
						BlinkInsertionPoint( null, window );			// this has to be done before the window is marked as deactivated
//					hexWindow->activeWindow = !hexWindow->activeWindow;	// bug: OS X is sending the event twice (naughty Apple!), so i shall do this more correctly as follows
					if( eventKind == kEventWindowActivated )
						hexWindow->activeWindow = true;
					else hexWindow->activeWindow = false;
					InvalidateWindowRect( window, &windowBounds );
					break;
				
				case kEventWindowBoundsChanging:
					error = hexWindow->BoundsChanging( event );
					break;
							
				case kEventWindowBoundsChanged:
					error = hexWindow->BoundsChanged( event );
					break;
							
				case kEventWindowDrawContent:
					error = hexWindow->DrawContent( event );
					break;
				
				case kEventWindowHandleContentClick:
				{	// get mouse
					Point mouse;
					error = GetEventParameter( event, kEventParamMouseLocation, typeQDPoint, null, sizeof(Point), null, &mouse );
					if( !error )
					{
						MakeLocal( window, mouse, &mouse );
						
						// get modifier keys
						UInt32 modifiers = null;
						error = GetEventParameter( event, kEventParamKeyModifiers, typeUInt32, null, sizeof(UInt32), null, &modifiers );
						if( error ) break;
						
						// identify click is in edit boxes & act accordingly
						Boolean	clickHex	= false;	// clicked in hex rect?
						Boolean	clickAscii	= false;	// clicked in ascii rect? - neither means not editing
						Plug_WindowRef plugWindow = Host_GetPlugWindowFromWindowRef( window );
						HexWindowPtr hexWindow = (HexWindowPtr) Host_GetWindowRefCon( plugWindow );
						if( PtInRect( mouse, &hexWindow->hexRect ) )	{ clickHex = true;		hexWindow->editingHex = true;		}
						if( PtInRect( mouse, &hexWindow->asciiRect ) )	{ clickAscii = true;	hexWindow->editingHex = false;	}
						if( clickHex || clickAscii )					error = HandleEditClick( window, event, mouse, (EventModifiers) LoWord(modifiers) );
						else error = eventNotHandledErr;
					}
					else error = eventNotHandledErr;
				}	break;
			}
			break;
		
		case kEventClassKeyboard:
			switch( eventKind )
			{
				case kEventRawKeyDown:
				case kEventRawKeyRepeat:
				{	signed char charCode;	// key character pressed
					UInt32 modifiers = null;
					error = GetEventParameter( event, kEventParamKeyMacCharCodes, typeChar, null, sizeof(char), null, &charCode );
					if( error ) break;
					error = GetEventParameter( event, kEventParamKeyModifiers, typeUInt32, null, sizeof(UInt32), null, &modifiers );
					if( error ) break;
					HandleKeyDown( window, charCode, (EventModifiers) LoWord(modifiers) );
				}	break;
			}
			
			// calculate new scrollbar values & redraw window
			hexWindow->UpdateHexInfo();
			InvalidateWindowRect( window, &windowBounds );
			break;
	}
	return error;
}

/*** CARBON HUMAN INTERFACE EVENT HANDLER ***/
pascal OSStatus CarbonHIEventHandler( EventHandlerCallRef handler, EventRef event, void *userData )
{
	#pragma unused( handler, userData )
	OSStatus		error = eventNotHandledErr;
	WindowRef		window = GetUserFocusWindow();	// overridden below for window class events
	if( !window )	return error;
	
	// get event type
	UInt32 eventClass = GetEventClass( event );
	UInt32 eventKind = GetEventKind( event );
	
	// get event parameters
	Plug_WindowRef plugWindow = Host_GetPlugWindowFromWindowRef( window );
	if( !plugWindow ) return error;
	HexWindowPtr hexWindow = (HexWindowPtr) Host_GetWindowRefCon( plugWindow );
	if( !hexWindow ) return error;
	
	// handle event
	switch( eventClass )
	{
		case kEventClassMenu:
			switch( eventKind )
			{
				case kEventMenuEnableItems:
				{	Plug_ResourceRef resource = Host_GetTargetResource( plugWindow );
					Boolean canPlaySound = false;
					if( Host_GetResourceType( resource ) == soundListRsrc )
						canPlaySound = true;
					
					// get host to set menus so we can modify them
					Host_UpdateMenus( resource );
					
					// edit menu
					EnableCommand( null, kHICommandUndo, false );
					EnableCommand( null, kHICommandRedo, false );
					EnableCommand( null, kHICommandCut, hexWindow->selStart != hexWindow->selEnd );
					EnableCommand( null, kHICommandCopy, hexWindow->selStart != hexWindow->selEnd );
					EnableCommand( null, kHICommandPaste, true );	// bug
					EnableCommand( null, kHICommandClear, hexWindow->selStart != hexWindow->selEnd );
					error = noErr;
				}	break;
			}
			break;
		
		case kEventClassCommand:		
			HICommand command;
			Plug_ResourceRef resource = Host_GetTargetResource( plugWindow );
			error = GetEventParameter( event, kEventParamDirectObject, typeHICommand, null, sizeof(HICommand), null, &command );
			if( error ) return eventNotHandledErr;
			switch( eventKind )
			{
				case kEventCommandProcess:
					switch( command.commandID )
					{
		/*				case kHICommandOK:
						case kHICommandCancel:
						case kHICommandQuit:
						case kHICommandUndo:
						case kHICommandRedo:
						case kHICommandCut:
							SendEventToWindow( copyEvent, window );
							SendEventToWindow( clearEvent, window );
							error = noErr;
							break;
		*/				
						case kHICommandCopy:
						{	// copy should be disabled if there isn't a selection, but just in caseÉ
							if( hexWindow->selStart == hexWindow->selEnd ) return error;
							
							// lock the data
							Size size;
							ScrapRef scrap;
							ClearCurrentScrap();
							error = GetCurrentScrap( &scrap );
							if( error ) return error;
							SInt8 state = HGetState( hexWindow->data );
							HLock( hexWindow->data );
							if( hexWindow->editingHex )
							{
								// copy data with hex formatting
								size = 3*(hexWindow->selEnd - hexWindow->selStart) -1;
								Ptr hex = NewPtrClear( size );
								Ptr ascii = NewPtrClear( hexWindow->selEnd - hexWindow->selStart );
								BlockMoveData( *hexWindow->data + hexWindow->selStart, ascii, hexWindow->selEnd - hexWindow->selStart );
								AsciiToHex( ascii, hex, hexWindow->selEnd - hexWindow->selStart );
								error = PutScrapFlavor( scrap, kScrapFlavorTypeText, kScrapFlavorMaskNone, size, hex );
								DisposePtr( hex );
								DisposePtr( ascii );
							}
							else
							{
								// copy raw data as byte stream
								size = hexWindow->selEnd - hexWindow->selStart;
								Ptr ascii = NewPtrClear( size );
								BlockMoveData( *hexWindow->data + hexWindow->selStart, ascii, size );
								error = PutScrapFlavor( scrap, kScrapFlavorTypeText, kScrapFlavorMaskNone, size, ascii );
								DisposePtr( ascii );
							}
							HSetState( hexWindow->data, state );
							error = noErr;
						}	break;
						
						case kHICommandPaste:
						{	Size size;
							ScrapRef scrap;
							error = GetCurrentScrap( &scrap );
							if( error ) return error;
							error = GetScrapFlavorSize( scrap, kScrapFlavorTypeText, &size );
							if( error ) return error;
							if( size > 0 )
							{
								Ptr bytes = NewPtr( size );
								error = GetScrapFlavorData( scrap, kScrapFlavorTypeText, &size, bytes );
								if( !error )
								{
									hexWindow->InsertBytes( null, hexWindow->selStart - hexWindow->selEnd, hexWindow->selEnd );	// remove this when using the above
									hexWindow->InsertBytes( bytes, size, hexWindow->selStart );
									hexWindow->selStart = hexWindow->selEnd += size;
								}
								DisposePtr( bytes );
								Host_SetResourceDirty( resource, true );
							}
							error = noErr;
						}	break;
						
						case kHICommandClear:
							hexWindow->InsertBytes( nil, hexWindow->selStart - hexWindow->selEnd, hexWindow->selEnd );
							hexWindow->selEnd = hexWindow->selStart;
							Host_SetResourceDirty( resource, true );
							error = noErr;
							break;
						
						case kHICommandSelectAll:
							hexWindow->selStart = 0;
							hexWindow->selEnd = GetHandleSize( hexWindow->data );
							error = noErr;
							break;
						
		/*				case kHICommandHide:
						case kHICommandPreferences:
						case kHICommandZoomWindow:
						case kHICommandMinimizeWindow:
						case kHICommandArrangeInFront:
						case kHICommandAbout:
		*/				default:
							error = eventNotHandledErr;
							break;
					}
					break;
				
				case kEventCommandUpdateStatus:
					error = eventNotHandledErr;
					break;
				
				default:
					error = eventNotHandledErr;
					break;
			}
			break;
	}
	
	// most calls need window updating, so do it here
	Rect windowBounds;
	hexWindow->UpdateHexInfo();
	GetWindowPortBounds( window, &windowBounds );
	InvalidateWindowRect( window, &windowBounds );
	return error;
}

#if !TARGET_API_MAC_CARBON

/*** CLASSIC WINDOW EVENT HANDLER ***/
pascal OSStatus ClassicWindowEventHandler( EventRecord *event, UInt32 eventKind, void *userData )
{
	#pragma unused( event, userData )
	OSStatus		error = eventNotHandledErr;
/*	Plug_PlugInRef	plugRef = (Plug_PlugInRef) userData;
	WindowRef		window;
	GetEventParameter( event, kEventParamDirectObject, typeWindowRef, null, sizeof(WindowRef), null, &window );
*/	
	switch( eventKind )
	{
		case kEventWindowDrawContent:
			error = DrawWindow( window );
			break;
		
		case kEventWindowHandleContentClick:
			SysBeep(0);
			break;
	}
	return error;
}

#endif

  /*****************/
 /* WINDOW EVENTS */
/*****************/

pascal OSStatus ConstrainWindowResize( EventHandlerCallRef handler, EventRef event, void *userData )
{
	#pragma unused( handler )
	Rect windowBounds;
	HexWindowPtr hexWindow = (HexWindowPtr) userData;
	OSStatus error = GetEventParameter( event, kEventParamCurrentBounds, typeQDRectangle, null, sizeof(Rect), null, &windowBounds );
	if( error ) return eventNotHandledErr;
	
	// constrain window width
	UInt8 modulo = (windowBounds.right - windowBounds.left - 13*kHexCharWidth - kScrollBarWidth) % (4*kDataBlockWidth);
	if( modulo < (2*kDataBlockWidth) )	windowBounds.right -= modulo;
	else								windowBounds.right += (4*kDataBlockWidth) - modulo;
	
	// constrain window height
	modulo = (windowBounds.bottom - windowBounds.top - kHeaderHeight - 2*kTextMargin -4) % kHexLineHeight;
	if( modulo < (kHexLineHeight/2) )	windowBounds.bottom -= modulo;
	else								windowBounds.bottom += kHexLineHeight - modulo;
	
	// update window rect to constrained version
	if( (windowBounds.bottom - windowBounds.top) < kMinimumWindowHeight )	windowBounds.bottom = windowBounds.top + kMinimumWindowHeight;
	if( (windowBounds.right - windowBounds.left) < kMinimumWindowWidth )	windowBounds.right = windowBounds.left + kMinimumWindowWidth;
	error = SetEventParameter( event, kEventParamCurrentBounds, typeQDRectangle, sizeof(Rect), &windowBounds );
	if( error ) error = eventNotHandledErr;
	
	// resize controls & update hex info
	hexWindow->BoundsChanged( event );
	return noErr;
}

  /***************/
 /* USER EVENTS */
/***************/

/*** HANDLE CLICK IN HEX/ASCII REGION ***/
OSStatus HandleEditClick( WindowRef window, EventRef event, Point mouse, EventModifiers modifiers )
{
	OSStatus error = eventNotHandledErr;
	
	// get hex info
	Plug_WindowRef plugWindow = Host_GetPlugWindowFromWindowRef( window );
	HexWindowPtr hexWindow = (HexWindowPtr) Host_GetWindowRefCon( plugWindow );
	
	// a mouse down event has been recieved and is within hexRect or asciiRect
	UInt16 clickLine;	// from zero, the line in which the click occoured
	UInt16 clickChar;	// 0 to 16, the char after the clickloc, or at line end
	
	// get line clicked on
	clickLine = (mouse.v - kHeaderHeight - kTextMargin)/kHexLineHeight + hexWindow->topline;
	if( clickLine > hexWindow->lastline )		// beyond last line
	{
		hexWindow->selStart = hexWindow->selEnd = GetHandleSize( hexWindow->data );
		return noErr;
	}
	
	// get char clicked on	-- duplicated in dragging routine
	if( hexWindow->editingHex )	clickChar = (mouse.h - kHexCharWidth *10) / (kHexCharWidth*3);
	else									clickChar = (mouse.h - kHexCharWidth *60) /  kHexCharWidth;
	
	// check for drags
	Point globalMouse;
	MakeGlobal( window, mouse, &globalMouse );
	Boolean dragging = WaitMouseMoved( globalMouse );
	unsigned long selectFromChar = (clickLine *16) + clickChar;
	unsigned long selectToChar = selectFromChar;
	
	// define selection region
	RgnHandle hexRgn = NewRgn(), asciiRgn = NewRgn(), selectedRgn = NewRgn();
	FindSelectedRegions( window, hexRgn, asciiRgn );
	UnionRgn( hexRgn, asciiRgn, selectedRgn );

	// drag current selection
	if( PtInRgn( mouse, selectedRgn ) && dragging )
	{
		OSErr error = noErr;
		DragReference theDragRef;
		ItemReference theItemRef = 1;
		FlavorFlags theFlags = nil;
		
		short		resCounter = 0;
		Size		dataSize = hexWindow->selEnd - hexWindow->selStart;
		RgnHandle	dragRgn = NewRgn(), subtractRgn = NewRgn();
		Handle		dataToDrag = NewHandleClear( dataSize * (hexWindow->editingHex? 3:1) - (hexWindow->editingHex? 1:0) );
		
		NewDrag( &theDragRef );
		if( MemError() ) return eventNotHandledErr;
		
		// get region of dragged items
		if( hexWindow->editingHex )	dragRgn = hexRgn;
		else						dragRgn = asciiRgn;
		CopyRgn( dragRgn, subtractRgn );				// duplicate region
		InsetRgn( subtractRgn, 2, 2 );					// inset it by 2 pixels
		DiffRgn( dragRgn, subtractRgn, dragRgn );		// subtract subRgn from dragRgn
		
		// get the drag data
		EventRecord eventRec;
		Boolean eventValid = ConvertEventRefToEventRecord( event, &eventRec );
		if( !eventValid ) eventValid = true;	// bug: for some reason the event converter is not returning valid events, but the drag still works
		if( dataToDrag && eventValid )
		{
			// I can't tell what the previous state of editingHex was, so cannot restore it.
			//	as such, i will redraw the window with the selection flipped if necessary
			hexWindow->DrawContent();
			
			SInt8 dataState = HGetState( hexWindow->data );
			SInt8 dragState = HGetState( dataToDrag );
			HLock( hexWindow->data );
			HLock( dataToDrag );
			if( hexWindow->editingHex )	AsciiToHex( *hexWindow->data + hexWindow->selStart, *dataToDrag, dataSize );
			else						BlockMoveData( *hexWindow->data + hexWindow->selStart, *dataToDrag, dataSize );
			HSetState( hexWindow->data, dataState );
			HSetState( dataToDrag, dragState );
			
			// do the drag
			SetPoint( &globalMouse, 0, 0 );
			MakeGlobal( window, globalMouse, &globalMouse );
			OffsetRgn( dragRgn, globalMouse.h, globalMouse.v );
			error = AddDragItemFlavor( theDragRef, theItemRef, kScrapFlavorTypeText, *dataToDrag, GetHandleSize(dataToDrag), theFlags );
			error = TrackDrag( theDragRef, &eventRec, dragRgn );
			
			// when dragging from the ACSII pane, drag will contain ÔasciiÕ, when dragging from the HEX pane, drag will contain Ô61 73 63 69 69Õ 
		}
		
		// clear up
		if( dataToDrag )	DisposeHandle( dataToDrag );
		if( theDragRef )	DisposeDrag( theDragRef );
		if( subtractRgn )	DisposeRgn( subtractRgn );
		if( dragRgn )		DisposeRgn( dragRgn );
	}
	
	// dragging new selection
	else if( dragging )
	{
		// remove insetion point if visable
		if( hexWindow->activeWindow && hexWindow->insertionPointVisable )
			BlinkInsertionPoint( null, window );
		
		Point localMouse;
		while( WaitMouseUp() )
		{
			// get local mouse co-ords
			GetMouse( &mouse );
			MakeLocal( window, mouse, &localMouse );
			
			// get line clicked on
			clickLine = (localMouse.v - kHeaderHeight - kTextMargin)/kHexLineHeight + hexWindow->topline;
			
			// get char clicked on
			if( hexWindow->editingHex )	clickChar = (localMouse.h - kHexCharWidth *10) / (kHexCharWidth*3);
			else						clickChar = (localMouse.h - kHexCharWidth *60) /  kHexCharWidth;
			
			// update selection according to mouse position and scroll to maintain visibility
			selectToChar = (clickLine *16) + clickChar;
			if( selectToChar < 0 )									selectToChar = 0;
			if( selectToChar > GetHandleSize(hexWindow->data) -1 )	selectToChar = GetHandleSize(hexWindow->data) -1;
			if( selectFromChar < selectToChar )
			{
				hexWindow->selStart = selectFromChar;
				hexWindow->selEnd = selectToChar +1;
//				hexScrollToLine( theWindow, clickLine, kBottomOfWindow );
			}
			else if( selectFromChar > selectToChar )
			{
				hexWindow->selStart = selectToChar;
				hexWindow->selEnd = selectFromChar;
//				hexScrollToLine( theWindow, clickLine, kTopOfWindow );
			}
			else
			{
				hexWindow->selStart = selectFromChar;
				hexWindow->selEnd = selectToChar +1;
			}
			
			// draw window
			hexWindow->DrawContent();
		}
	}
	
	// change cursor position
	else
	{
		// remove insertion point if visable
		if( hexWindow->activeWindow && hexWindow->insertionPointVisable )
			BlinkInsertionPoint( null, window );
		
		if( modifiers & shiftKey )	// extend selection
		{
			if( selectFromChar < hexWindow->selStart )	hexWindow->selStart = selectFromChar;
			else										hexWindow->selEnd = selectFromChar +1;
		}
		else						// normal click
		{
			if( mouse.v < GetHandleSize(hexWindow->data) )	hexWindow->selStart = selectFromChar;
			else											hexWindow->selStart = GetHandleSize(hexWindow->data);
															hexWindow->selEnd = selectToChar;
		}
		
		if( hexWindow->selStart < 0 )								hexWindow->selStart = 0;
		if( hexWindow->selEnd > GetHandleSize(hexWindow->data) )	hexWindow->selEnd = GetHandleSize(hexWindow->data);
		
		// invalidate window incase there was a selection
		Rect windowBounds;
		GetWindowPortBounds( window, &windowBounds );
		InvalidateWindowRect( window, &windowBounds );
	}
	
	DisposeRgn( hexRgn );
	DisposeRgn( asciiRgn );
	DisposeRgn( selectedRgn );
	return noErr;
}

/*** HANDLE EDIT DRAG ***/
OSStatus HandleEditDrag( WindowRef window, EventRef event, Point mouse, EventModifiers modifiers )
{
	#pragma unused( window, event, mouse, modifiers )
	return eventNotHandledErr;
}

/*** HANDLE KEY DOWN ***/
OSStatus HandleKeyDown( WindowRef window, unsigned char charCode, EventModifiers modifiers )
{
	OSStatus error = eventNotHandledErr;
	
	// get hex info
	Plug_WindowRef plugWindow = Host_GetPlugWindowFromWindowRef( window );
	Plug_ResourceRef resource = Host_GetTargetResource( plugWindow );
	HexWindowPtr hexWindow = (HexWindowPtr) Host_GetWindowRefCon( plugWindow );
	
	// handle arrow keys
	Boolean resEdited = false;
	switch( charCode )
	{
		case kTabCharCode:
		case kEnterCharCode:
		case kReturnCharCode:
			hexWindow->editingHex = !hexWindow->editingHex;
			break;
		
		case kBackspaceCharCode:		// delete
			if( hexWindow->selStart == hexWindow->selEnd ) {
				if( hexWindow->selStart != 0 ) {
					hexWindow->InsertBytes( nil, -1, hexWindow->selEnd );									// delete prev char
					hexWindow->selStart = hexWindow->selEnd -= 1; } }
			else {
				hexWindow->InsertBytes( nil, hexWindow->selStart - hexWindow->selEnd, hexWindow->selEnd );	// remove selection
				hexWindow->selEnd = hexWindow->selStart; }
			
			Host_SetResourceDirty( resource, true );
			break;

		case kDeleteCharCode:			// forward delete
			if( hexWindow->selStart == hexWindow->selEnd )
			{
				if( hexWindow->selStart != GetHandleSize( hexWindow->data ) )
					hexWindow->InsertBytes( nil, -1, hexWindow->selEnd +1 );								// delete next char
			}
			else
			{
				hexWindow->InsertBytes( nil, hexWindow->selStart - hexWindow->selEnd, hexWindow->selEnd );	// remove selection
				hexWindow->selEnd = hexWindow->selStart;
			}
			Host_SetResourceDirty( resource, true );
			break;

		case kLeftArrowCharCode:
		case kRightArrowCharCode:
		case kUpArrowCharCode:
		case kDownArrowCharCode:
			error = HandleArrowKeyDown( window, charCode, modifiers );
			break;
		
		default:
			if( hexWindow->editingHex )		// editing in hexadecimal
			{
				Boolean deletePrev = false;	// delete prev typing to add new one
				if( hexWindow->editedHigh )	// edited high bits already
				{
					// shift typed char into high bits and add new low char
					if( charCode >= 0x30 && charCode <= 0x39 )		charCode -= 0x30;		// 0 to 9
					else if( charCode >= 0x61 && charCode <= 0x66 )	charCode -= 0x57;		// a to f
					else if( charCode >= 0x93 && charCode <= 0x98 )	charCode -= 0x8A;		// A to F
					else break;
					hexWindow->hexChar <<=  4;				// store high bit
				 	hexWindow->hexChar += charCode & 0x0F;	// add low bit
					hexWindow->selStart += 1;
					hexWindow->selEnd = hexWindow->selStart;
					hexWindow->editedHigh = false;
					deletePrev = true;
				}
				else				// editing low bits
				{
					// put typed char into low bits
					if( charCode >= 0x30 && charCode <= 0x39 )		charCode -= 0x30;		// 0 to 9
					else if( charCode >= 0x61 && charCode <= 0x66 )	charCode -= 0x57;		// a to f
					else if( charCode >= 0x93 && charCode <= 0x98 )	charCode -= 0x8A;		// A to F
					else break;
					hexWindow->hexChar = charCode & 0x0F;
					hexWindow->editedHigh = true;
				}
				hexWindow->InsertBytes( nil, hexWindow->selStart - hexWindow->selEnd, hexWindow->selEnd );	// remove selection
				hexWindow->selEnd = hexWindow->selStart;
				if( deletePrev )
				{
					hexWindow->InsertBytes( nil, -1, hexWindow->selStart );									// remove previous hex char
					hexWindow->InsertBytes( &hexWindow->hexChar, 1, hexWindow->selStart -1 );				// insert typed char (bug fix hack)
				}
				else hexWindow->InsertBytes( &hexWindow->hexChar, 1, hexWindow->selStart );					// insert typed char
			}
			else					// editing in ascii
			{
				hexWindow->InsertBytes( nil, hexWindow->selStart - hexWindow->selEnd, hexWindow->selEnd );	// remove selection
				hexWindow->selEnd = hexWindow->selStart;
				hexWindow->InsertBytes( &charCode, 1, hexWindow->selStart );								// insert typed char
				hexWindow->selStart += 1;
				hexWindow->selEnd = hexWindow->selStart;
			}
			Host_SetResourceDirty( resource, true );
			break;
	}
	
	// check selection is within resource
	if( hexWindow->selStart > hexWindow->selEnd )				hexWindow->selStart = hexWindow->selEnd;
	if( hexWindow->selStart > GetHandleSize(hexWindow->data) )	hexWindow->selStart = GetHandleSize(hexWindow->data);
	if( hexWindow->selEnd > GetHandleSize(hexWindow->data) )	hexWindow->selEnd   = GetHandleSize(hexWindow->data);
	
	// modify key pressed so scroller interperets it correctly
	if( modifiers & controlKey ) switch( charCode )
	{
		case kUpArrowCharCode:
			charCode = kDownArrowCharCode;
			break;
		
		case kDownArrowCharCode:
			charCode = kUpArrowCharCode;
			break;
		
		case kLeftArrowCharCode:
			charCode = kRightArrowCharCode;
			break;
		
		case kRightArrowCharCode:
			charCode = kLeftArrowCharCode;
			break;
	}

	// get scrollbar
#if TARGET_API_MAC_CARBON
	ControlRef scrollbar;
	ControlID id = { kScrollbarSignature, 0 };
	GetControlByID( window, &id, &scrollbar );
#else
	ControlRef scrollbar = hexWindow->scrollbar;
#endif
	
	// scroll to selection
	switch( charCode )
	{
		case kUpArrowCharCode:
			if( hexWindow->selStart /16 < hexWindow->topline +1 )
				SetControlValue( scrollbar, hexWindow->selStart /16 -1 );
			break;
		
		case kDownArrowCharCode:
			if( hexWindow->selEnd /16 > hexWindow->bottomline -1 )
				SetControlValue( scrollbar, hexWindow->selEnd /16 - (hexWindow->bottomline - hexWindow->topline) +1 );
			break;
		
		case kBackspaceCharCode:
		case kLeftArrowCharCode:
			if( hexWindow->selStart /16 < hexWindow->topline +1 )
				SetControlValue( scrollbar, hexWindow->selStart /16 -1 );
			break;
		
		case kRightArrowCharCode:
		default:
			if( hexWindow->selEnd /16 > hexWindow->bottomline -1 )
				SetControlValue( scrollbar, hexWindow->selEnd /16 - (hexWindow->bottomline - hexWindow->topline) +1 );
			break;
	}
	return error;
}

/*** HANDLE ARROW KEY DOWN ***/
OSStatus HandleArrowKeyDown( WindowRef window, unsigned char charCode, EventModifiers modifiers )
{
	OSStatus error = noErr;
	
	// get hex info
	Plug_WindowRef plugWindow = Host_GetPlugWindowFromWindowRef( window );
	Plug_ResourceRef resource = Host_GetTargetResource( plugWindow );
	HexWindowPtr hexWindow = (HexWindowPtr) Host_GetWindowRefCon( plugWindow );
	
	if( modifiers & optionKey ) switch( charCode )	// move selection
	{
		case kLeftArrowCharCode:
			hexWindow->selStart	-= 1;
			hexWindow->selEnd	-= 1;
			break;
		case kRightArrowCharCode:
			hexWindow->selStart	+= 1;
			hexWindow->selEnd	+= 1;
			break;
		case kUpArrowCharCode:
			hexWindow->selStart	-= 16;
			hexWindow->selEnd	-= 16;
			break;
		case kDownArrowCharCode:
			hexWindow->selStart	+= 16;
			hexWindow->selEnd	+= 16;
			break;
	}
	
	else if( modifiers & shiftKey ) switch( charCode )	// extend selection
	{
		case kLeftArrowCharCode:
			hexWindow->selStart	-= 1;
			break;
		case kRightArrowCharCode:
			hexWindow->selEnd	+= 1;
			break;
		case kUpArrowCharCode:
			hexWindow->selStart	-= 16;
			break;
		case kDownArrowCharCode:
			hexWindow->selEnd	+= 16;
			break;
	}
	
	else if( modifiers & controlKey ) switch( charCode )	// reduce selection
	{
		case kLeftArrowCharCode:
			hexWindow->selEnd	-= 1;
			break;
		case kRightArrowCharCode:
			hexWindow->selStart	+= 1;
			break;
		case kUpArrowCharCode:
			hexWindow->selEnd	-= 16;
			break;
		case kDownArrowCharCode:
			hexWindow->selStart	+= 16;
			break;
	}
	
	else switch( charCode )									// move cursor
	{
		case kLeftArrowCharCode:
			if( hexWindow->selStart == hexWindow->selEnd )
			{
				if( hexWindow->selStart >= 1 )	hexWindow->selStart	-= 1;
				if( hexWindow->selEnd >= 1 )	hexWindow->selEnd	-= 1;
			}
			else hexWindow->selEnd = hexWindow->selStart;
			hexWindow->editedHigh = false;
			break;
		
		case kRightArrowCharCode:
			if( hexWindow->selStart == hexWindow->selEnd )
			{
				hexWindow->selStart += 1;
				hexWindow->selEnd += 1;
			}
			else hexWindow->selStart = hexWindow->selEnd;
			hexWindow->editedHigh = false;
			break;
		
		case kUpArrowCharCode:
			if( hexWindow->selStart == hexWindow->selEnd )
			{
				if( hexWindow->selStart >= 16 )	hexWindow->selStart	-= 16;
				else							hexWindow->selStart	= 0;
				if( hexWindow->selEnd >= 16 )	hexWindow->selEnd	-= 16;
				else							hexWindow->selEnd	= 0;
			}
			else hexWindow->selEnd = hexWindow->selStart;
			hexWindow->editedHigh = false;
			break;
		
		case kDownArrowCharCode:
			if( hexWindow->selStart == hexWindow->selEnd ) {
				hexWindow->selStart += 16;
				hexWindow->selEnd += 16; }
			else hexWindow->selStart = hexWindow->selEnd;
			hexWindow->editedHigh = false;
			break;
	}
	
	return error;
}

/*** FIND SELECTED REGIONS ***/
OSStatus FindSelectedRegions( WindowRef window, RgnHandle hexRgn, RgnHandle asciiRgn )
{
	// get hex info structure
	Plug_WindowRef plugWindow = Host_GetPlugWindowFromWindowRef( window );
	HexWindowPtr hexWindow = (HexWindowPtr) Host_GetWindowRefCon( plugWindow );
	
	// get window bounds
	Rect windowBounds, subtractRect;
	RgnHandle subtractRgn = NewRgn();
	GetWindowPortBounds( window, &windowBounds );
	
	// start and end points of selection relative to first visable char
	Boolean clipTop, clipBottom;
	signed long startLine = hexWindow->selStart/16 - hexWindow->topline;
	signed long endLine = (hexWindow->selEnd - hexWindow->selEnd %16)/16 - hexWindow->topline +1;
	
	// find hex region
	Rect hexSelRect;
	SetRect( &hexSelRect, kHexCharWidth *11 -1, startLine * kHexLineHeight, kHexCharWidth *58 +1, endLine * kHexLineHeight );
	OffsetRect( &hexSelRect, 0, kHeaderHeight + kTextMargin + 2 );
	clipTop				= hexSelRect.top < kHeaderHeight + kTextMargin +2;
	clipBottom			= hexSelRect.bottom > windowBounds.bottom - kTextMargin -2;
	if( clipTop )		hexSelRect.top = kHeaderHeight + kTextMargin +2;
	if( clipBottom )	hexSelRect.bottom = windowBounds.bottom - kTextMargin -2;
	RectRgn( hexRgn, &hexSelRect );
	
	if( !clipTop )
	{
		SetRect( &subtractRect, hexSelRect.left, hexSelRect.top, hexSelRect.left + (hexWindow->selStart % 16) * (kHexCharWidth *3), hexSelRect.top + kHexLineHeight );
		RectRgn( subtractRgn, &subtractRect );
		DiffRgn( hexRgn, subtractRgn, hexRgn );
	}
	
	if( !clipBottom )
	{
		SetRect( &subtractRect, hexSelRect.right - (16 - hexWindow->selEnd % 16) * (kHexCharWidth *3), hexSelRect.bottom - kHexLineHeight, hexSelRect.right, hexSelRect.bottom );
		RectRgn( subtractRgn, &subtractRect );
		DiffRgn( hexRgn, subtractRgn, hexRgn );
	}
		
	// find ascii region
	Rect asciiSelRect;
	SetRect( &asciiSelRect, kHexCharWidth *60 -1, startLine * kHexLineHeight, kHexCharWidth *76 +1, endLine * kHexLineHeight );
	OffsetRect( &asciiSelRect, 0, kHeaderHeight + kTextMargin + 2 );
	if( clipTop )		asciiSelRect.top = kHeaderHeight + kTextMargin +2;
	if( clipBottom )	asciiSelRect.bottom = windowBounds.bottom - kTextMargin -2;
	RectRgn( asciiRgn, &asciiSelRect );
	
	if( !clipTop )
	{
		SetRect( &subtractRect, asciiSelRect.left, asciiSelRect.top, asciiSelRect.left + (hexWindow->selStart % 16) * kHexCharWidth, asciiSelRect.top + kHexLineHeight );
		RectRgn( subtractRgn, &subtractRect );
		DiffRgn( asciiRgn, subtractRgn, asciiRgn );
	}
	
	if( !clipBottom )
	{
		SetRect( &subtractRect, asciiSelRect.right - (16 - hexWindow->selEnd % 16) * kHexCharWidth, asciiSelRect.bottom - kHexLineHeight, asciiSelRect.right, asciiSelRect.bottom );
		RectRgn( subtractRgn, &subtractRect );
		DiffRgn( asciiRgn, subtractRgn, asciiRgn );
	}
	
	// clear up
	DisposeRgn( subtractRgn );
	return noErr;
}

/*** UPDATE SELECTION ***/
OSStatus UpdateSelection( WindowRef window, Boolean editingHex )
{
	// get controls
	ControlRef root, hex, ascii;
	GetRootControl( window, &root );
	GetIndexedSubControl( root, 3, &hex );
	GetIndexedSubControl( root, 4, &ascii );
	
	// reflect selection
	Size actualSize;
	ControlEditTextSelectionRec selection;
	GetControlData( editingHex? hex:ascii, kControlEditTextPart, kControlEditTextSelectionTag, sizeof(ControlEditTextSelectionRec), &selection, &actualSize );
	if( editingHex )
	{
		selection.selStart /= 3;
		selection.selEnd = (selection.selEnd +1) /3;
	}
	else
	{
		selection.selStart *= 3;
		selection.selEnd = (selection.selEnd *3) -1;
	}
	SetControlData( editingHex? ascii:hex, kControlEditTextPart, kControlEditTextSelectionTag, actualSize, &selection );
	return noErr;
}

  /********************/
 /* CONTROL HANDLING */
/********************/

/*** TRACK SCROLL BAR ***/
pascal void TrackScrollbar( ControlRef control, short part )
{
	WindowRef window = GetControlOwner(control);
	Plug_WindowRef plugWindow = Host_GetPlugWindowFromWindowRef( window );
	HexWindowPtr hexWindow = (HexWindowPtr) Host_GetWindowRefCon( plugWindow );
	
	// decide how many lines to scroll ( and in which direction )
	short startValue, delta, endValue, max;
	if( !part ) return;
	switch( part )
	{
		case kControlUpButtonPart:			// up (20)
			delta = -1;
		  	break;
			
		case kControlDownButtonPart:		// down (21)
			delta = 1;
		  	break;
			
		case kControlPageUpPart:			// page up (22)
			delta = hexWindow->topline - hexWindow->bottomline +1;
		  	break;
			
		case kControlPageDownPart:			// page down (23)
			delta = hexWindow->bottomline - hexWindow->topline -1;
		  	break;
			
		default:
		 	delta = 0;
		 	break;
	}

	// calculate and correct control value
	max			= GetControlMaximum( control );
	startValue	= GetControlValue( control );
	endValue	= startValue + delta;
	if( endValue < 0 )		endValue = 0;
	if( endValue > max )	endValue = max;
	SetControlValue( control, endValue );
	hexWindow->UpdateHexInfo();	
	
	// update the window
//	InvalidateWindowRect( window, &windowBounds );	// doesn't update live scroll immediatly anyway, so may as well not call it
	hexWindow->DrawContent();
}

  /******************/
 /* TIMER ROUTINES */
/******************/

/*** BLINK INSERTION POINT ***/
pascal void BlinkInsertionPoint( EventLoopTimerRef inTimer, void *inUserData )
{
	#pragma unused( inTimer )	// inTimer can be null (if routine was not called from a timer)
	
	// get window's info structure
	WindowRef window = (WindowRef) inUserData;
	Plug_WindowRef plugWindow = Host_GetPlugWindowFromWindowRef( window );
	HexWindowPtr hexWindow = (HexWindowPtr) Host_GetWindowRefCon( plugWindow );
	
	// if not focus window, don't flash cursor
	if( !hexWindow->activeWindow ) return;
	
	// if there's a selection, don't flash cursor
	if( hexWindow->selStart != hexWindow->selEnd ) return;
	
	// if insertion point is not within visable region, don't flash cursor
	if( hexWindow->selStart < hexWindow->topline * 16 ) return;
	if( hexWindow->selEnd >= (hexWindow->bottomline +1) * 16 ) return;
	
	GrafPtr oldPort;
	GetPort( &oldPort );
	SetPortWindowPort( window );
	Rect blinkRect;
	
	long theStart = hexWindow->selStart - hexWindow->topline * 16;
	long theEnd = hexWindow->selEnd - hexWindow->topline * 16;
	if( hexWindow->editingHex )	SetRect( &blinkRect,	kHexCharWidth *11 + (theStart %16) * (kHexCharWidth *3) -1,	(theStart /16) * kHexLineHeight + kTextMargin +2,
														kHexCharWidth *11 + (theStart %16) * (kHexCharWidth *3) +1,	(theStart /16) * kHexLineHeight + kTextMargin +2 + kHexLineHeight );
	else						SetRect( &blinkRect,	kHexCharWidth *60 + (theStart %16) * kHexCharWidth -1,		(theStart /16) * kHexLineHeight + kTextMargin +2,
														kHexCharWidth *60 + (theStart %16) * kHexCharWidth +1,		(theStart /16) * kHexLineHeight + kTextMargin +2 + kHexLineHeight );
	OffsetRect( &blinkRect, 0, kHeaderHeight );
	InvertRect( &blinkRect );
	hexWindow->insertionPointVisable = !hexWindow->insertionPointVisable;
	
	SetPort( oldPort );
}