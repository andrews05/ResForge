#include "Application.h"
#include "Asynchronous.h"	// for initing, idling, and disposing
#include "Errors.h"
#include "Files.h"			// for open & save etc.
#include "FileWindow.h"		// no particuar reason
#include "ResourceObject.h"
#include "Utility.h"

// set up prefs and globals
globals g;
prefs p;

/*** MAIN ***/
int main( int argc, char* argv[] )
{
	#pragma unused( argc, argv )
	
	// get system version
	OSStatus error = Gestalt( gestaltSystemVersion, &g.systemVersion );		// this loads HIToolbox.framework on OS X
	if( error ) return error;
	
	// initalise application
	error = InitToolbox();
	if( error ) return error;
	error = InitMenubar();
	if( error ) return error;
	error = InitAppleEvents();
	if( error ) return error;
	error = InitCarbonEvents();
	if( error ) return error;
	error = InitGlobals();
	if( error ) return error;
			InitCursor();
	
	// check system version is at least 7.1
	if( g.systemVersion < kMacOS71 )
	{
		DisplayError( kStringOSNotGoodEnough, kExplanationOSNotGoodEnough );
		QuitResKnife();
	}
	
#if TARGET_API_MAC_CARBON
	// check carbon version is at least 1.1
	error = Gestalt( gestaltCarbonVersion, &g.carbonVersion );
	if( g.carbonVersion < kCarbonLib11 || error )
	{
		DisplayError( kStringMinimumCarbonLib, kExplanationMinimumCarbonLib );
		QuitResKnife();
	}
	else if( g.carbonVersion < kCarbonLib131 )
	{
		DisplayError( kStringRecommendedCarbonLib, kExplanationRecommendedCarbonLib );
	}
#endif
	
#if __profile__
	error = ProfilerInit( collectDetailed, bestTimeBase, 400, 40 );
	if( error )	DebugStr( "\pProfiler initalisation failed" );		// profiler failed
#endif

#if TARGET_API_MAC_CARBON
	// run event loop
	RunApplicationEventLoop();
#else
	EventRecord theEvent;
	while( !g.quitting )
	{
		WaitNextEvent( everyEvent, &theEvent, 20, null );
		if( IsDialogEvent( &theEvent ) )
			ParseDialogEvents( null, &theEvent, null );
		else ParseEvents( &theEvent );
	}
	QuitResKnife();
#endif
	
#if __profile__
	ProfilerDump( "\pResKnife profile" );
	ProfilerTerm();
#endif

	return error;
}

/*** INIT TOOLBOX ***/
OSStatus InitToolbox( void )
{
#if !TARGET_API_MAC_CARBON
	InitGraf( &qd.thePort );
	InitFonts();
	FlushEvents( everyEvent, 0 );
	InitWindows();
	InitMenus();
	TEInit();
	InitDialogs( 0L );
#endif
	return noErr;
}

/*** INITALIZE MENUBAR ***/
OSStatus InitMenubar( void )
{
	OSStatus error = noErr;
	
#if USE_NIBS
	IBNibRef nibRef = null;
	
	// create a nib reference (only searches the application bundle)
	error = CreateNibReference( CFSTR("ResKnife"), &nibRef );
	if( error != noErr )
	{
		DisplayError( "\pThe nib file reference could not be obtained." );
		return error;
	}
	
	// get menu bar
	error = SetMenuBarFromNib( nibRef, CFSTR("Menubar") );
	if( error != noErr )
	{
		DisplayError( "\pMenus could not be obtained from nib file." );
		return error;
	}
	
	// dispose of nib ref
	DisposeNibReference( nibRef );
	
#else	/* ! USE_NIBS */
	
	Handle menuList = GetNewMBar( kClassicMenuBar );
	SetMenuBar( menuList );
	ReleaseResource( menuList );
	
	// delete quit and prefs on OS X
	long result;
	error = Gestalt( gestaltMenuMgrAttr, &result );
	if( !error && (result & gestaltMenuMgrAquaLayoutMask) )
	{
		MenuRef fileMenu = GetMenuRef( kFileMenu );
		MenuRef editMenu = GetMenuRef( kEditMenu );
		DeleteMenuItem( fileMenu, kFileMenuQuitItem );
		DeleteMenuItem( fileMenu, kFileMenuQuitItem -1 );
		DeleteMenuItem( editMenu, kEditMenuPreferencesItem );
		DeleteMenuItem( editMenu, kEditMenuPreferencesItem -1 );
	}
	
	// set delete item character to the delete glyph
	MenuRef editMenu = GetMenuRef( kEditMenu );
	SetMenuItemKeyGlyph( editMenu, kEditMenuClearItem, kMenuDeleteLeftGlyph );
	
#if TARGET_API_MAC_CARBON
	MenuRef windowMenu;
	CreateStandardWindowMenu( 0, &windowMenu );
	InsertMenu( windowMenu, kWindowMenu );
#else
	AppendResMenu( GetMenuRef( kAppleMenu ), 'DRVR' );
#endif	/* TARGET_CARBON */
	DrawMenuBar();
	
#endif	/* USE_NIBS */
	
	return error;
}

/*** INIT APPLE EVENTS ***/
OSStatus InitAppleEvents( void )
{
	AEEventHandlerUPP appleEventParser = NewAEEventHandlerUPP( ParseAppleEvents );
	AEInstallEventHandler( kCoreEventClass,	kAEOpenApplication,			appleEventParser, 0, false );
	AEInstallEventHandler( kCoreEventClass,	kAEReopenApplication,		appleEventParser, 0, false );
	AEInstallEventHandler( kCoreEventClass,	kAEOpenDocuments,			appleEventParser, 0, false );
	AEInstallEventHandler( kCoreEventClass,	kAEPrintDocuments,			appleEventParser, 0, false );
	AEInstallEventHandler( kCoreEventClass,	kAEQuitApplication,			appleEventParser, 0, false );
	return noErr;
}

/*** INIT CARBON EVENTS ***/
OSStatus InitCarbonEvents( void )
{
#if TARGET_API_MAC_CARBON
	EventHandlerUPP handler	= null;
	EventHandlerRef	ref		= null;
	EventTypeSpec	update	= { kEventClassMenu,	kEventMenuEnableItems };
	EventTypeSpec	process	= { kEventClassCommand,	kEventCommandProcess };
	
	// install menu adjust handler
	handler	= NewEventHandlerUPP( CarbonEventUpdateMenus );
	InstallApplicationEventHandler( handler, 1, &update, null, &ref );
	
	// install menu selection handler
	handler	= NewEventHandlerUPP( CarbonEventParseMenuSelection );
	InstallApplicationEventHandler( handler, 1, &process, null, &ref );
	
	// install default idle timer Ñ 200 millisecond interval - bug: this should be in a seperate thread and the cursor blink time
	EventLoopTimerUPP timerUPP = NewEventLoopTimerUPP( DefaultIdleTimer );
	OSStatus error = InstallEventLoopTimer( GetMainEventLoop(), kEventDurationNoWait, kEventDurationMillisecond * 200, timerUPP, null, &g.idleTimer );
	return error;
#else
	return noErr;
#endif
}

/*** INITALIZE GLOBALS ***/
OSStatus InitGlobals( void )
{
	OSStatus error = noErr;
	
	// general app globals
	g.quitting		= false;
	g.cancelQuit	= false;
	g.frontApp		= true;
	g.appResFile	= CurResFile();
	g.asyncSound	= !(Boolean) SHInitSoundHelper( &g.callSH, kSHDefChannels );
	g.emergencyMemory = NewHandleClear( kEmergencyMemory );
	
	// files
	g.tempCount		= 0;
	
	// debugging
	g.debug			= false;
	g.surpressErrors = false;
	g.useAppleEvents = true;
	g.useSheets		= (g.carbonVersion >= kCarbonLib11)? true:false;
	
	// prefs dialog
	g.prefsDialog	= null;
	p.warnOnDelete	= true;
	
	// colours
	SetColour( &g.white,		0xFFFF, 0xFFFF, 0xFFFF );
	SetColour( &g.bgColour,		0xEEEE, 0xEEEE, 0xEEEE );
	SetColour( &g.sortColour,	0xDDDD, 0xDDDD, 0xDDDD );
	SetColour( &g.bevelColour,	0xAAAA, 0xAAAA, 0xAAAA );
	SetColour( &g.textColour,	0x7777, 0x7777, 0x7777 );
	SetColour( &g.frameColour,	0x5555, 0x5555, 0x5555 );
	SetColour( &g.black,		0x0000, 0x0000, 0x0000 );
	
#if TARGET_API_MAC_CARBON
	// window manager
	g.windowMgrAvailable = true;
	g.extendedWindowAttr = true;
	
	// drag manager
	g.dragAvailable = true;
	g.translucentDrag = true;
	
	// appearance manager
	g.appearanceAvailable = true;
	g.useAppearance = g.appearanceAvailable;			// assume if user has Appearence, s/he wants to use it
	if( g.useAppearance ) RegisterAppearanceClient();	// register such with the OS
	
	// nav services
	g.navAvailable = true;
	g.useNavServices = g.navAvailable;		// assume if user has NavServices, s/he wants to use them
	if( g.navAvailable ) NavLoad();			// preload for efficiency - ignored on OS X (always loaded)
#else
	// check for drag manager presence/attributes
	SInt32 result = null;
	error = Gestalt( gestaltDragMgrAttr, &result );
	if( !error ) {
		g.dragAvailable = (Boolean) (result & (1 << gestaltDragMgrPresent));
		g.translucentDrag = (Boolean) (result & (1 << gestaltDragMgrHasImageSupport)); }
	else {
		g.dragAvailable = false;
		g.translucentDrag = false; }
	
	// check appearance availablilty
	result = null;
	error = Gestalt( gestaltAppearanceAttr, &result );
	if( !error ) {
		g.appearanceAvailable = (Boolean) (result & (1 << gestaltAppearanceExists));
		g.useAppearance = g.appearanceAvailable; }		// assume if user has Appearence, s/he wants to use it
	else {
		g.appearanceAvailable = false;
		g.useAppearance = false; }
	if( g.useAppearance ) RegisterAppearanceClient();	// register such with the OS
	
	// check nav services availablilty
	g.navAvailable = (Boolean) NavServicesAvailable();
	g.useNavServices = g.navAvailable;		// assume if user has NavServices, s/he wants to use them
	if( g.navAvailable ) NavLoad();			// preload for efficiency
	
	// check for MacOS 8.5's window manager (also in CarbonLib 1.0 - backported to 8.1)
	result = null;
	error = Gestalt( gestaltWindowMgrAttr, &result );
	if( !error ) {
		g.windowMgrAvailable = (Boolean) (result & (1 << gestaltWindowMgrPresentBit));
		g.extendedWindowAttr = (Boolean) (result & (1 << gestaltExtendedWindowAttributes)); }
	else {
		g.windowMgrAvailable = false;
		g.extendedWindowAttr = false; }
	
	UpdateMenus( null );
#endif
	return error;
}

#if !TARGET_API_MAC_CARBON

/*** PARSE EVENTS ***/
OSStatus ParseEvents( EventRecord *event )
{
	OSStatus error = eventNotHandledErr;
	switch( event->what )
	{
		case nullEvent:
			IdleEvent();
			break;
		case mouseDown:
			error = MouseDownEventOccoured( event );
			break;
		case mouseUp:
			error = MouseUpEventOccoured( event );
			break;
		case keyDown:
			error = KeyDownEventOccoured( event );
			break;
		case autoKey:
			error = KeyRepeatEventOccoured( event );
			break;
		case keyUp:
			error = KeyUpEventOccoured( event );
			break;
		case updateEvt:
			error = UpdateEventOccoured( event );
			break;
		case activateEvt:
			error = ActivateEventOccoured( event );
			break;
		case osEvt:
			error = ParseOSEvents( event );
			break;
		case kHighLevelEvent:
			error = AEProcessAppleEvent( event );
			break;
	}
	return error;
}

/*** PARSE DIALOG EVENTS ***/
pascal Boolean ParseDialogEvents( DialogPtr dialog, EventRecord *event, DialogItemIndex *itemHit )
{
	#pragma unused( dialog, event, itemHit )
/*	OSStatus error = eventNotHandledErr;
	if( dialog == null && itemHit == null );
*/	return false;
}

/*** PARSE OS EVENTS ***/
OSStatus ParseOSEvents( EventRecord *event )
{
	#pragma unused( event )
	OSStatus error = eventNotHandledErr;
	SInt8 eventType = event->message >> 24;	// high byte of message field
	if( eventType & mouseMovedMessage )
	{
		// mouse moved event
	}
	else if( eventType & suspendResumeMessage )				// suspend/resume event
	{
		g.frontApp = ( event->message & resumeFlag );		// true on resume
		if( FrontWindow() )									// only de/activate front window (if present)
		{
			WindowObjectPtr winObj = (WindowObjectPtr) GetWindowRefCon( FrontWindow() );
			error = winObj->Activate( g.frontApp );
		}
		if( event->message & convertClipboardFlag )
		{
			// convert clipboard to private scrap
		}					
	}
	else error = paramErr;
	return error;
}

#endif

/*** PARSE APPLE EVENTS ***/
pascal OSErr ParseAppleEvents( const AppleEvent *event, AppleEvent *reply, SInt32 refCon )
{
	#pragma unused( reply, refCon )
	
	OSErr		error;
	Size		actualSize;
	DescType	actualType;
	DescType	eventClass, eventID;
	
	error = AEGetAttributePtr( (AppleEvent *) event, keyEventClassAttr, typeType, &actualType, (Ptr) &eventClass, sizeof(eventClass), &actualSize );
	if( error ) return errAEEventNotHandled;
				
	error = AEGetAttributePtr( (AppleEvent *) event, keyEventIDAttr, typeType, &actualType, (Ptr) &eventID, sizeof(eventID), &actualSize );
	if( error ) return errAEEventNotHandled;
	
	switch( eventClass )
	{
		case kCoreEventClass:
			switch( eventID )
			{
				case kAEOpenApplication:		// sent when app opened directly (ie not file opened)
#if TARGET_API_MAC_CARBON
											DisplayOpenDialog();
#else
					if( g.useNavServices )	DisplayOpenDialog();
					else					DisplayStandardFileOpenDialog();
#endif
					break;
					
				case kAEReopenApplication:		// sent when app is double-clicked on, but is already open
					if( FrontWindow() == null )
					{
						AEDescList list = {};
#if TARGET_API_MAC_CARBON
													AppleEventSendSelf( kCoreEventClass, kAEOpenApplication, list );
#else
						if( g.useAppleEvents )		AppleEventSendSelf( kCoreEventClass, kAEOpenApplication, list );
						else if( g.useNavServices )	DisplayOpenDialog();
						else						DisplayStandardFileOpenDialog();
#endif
					}
					break;
				
				case kAEOpenDocuments:			// sent when file is double-clicked on in finder,
					AppleEventOpen( event );	//	or open is chosen in the file menu and g.useAppleEvents is true
					break;
					
				case kAEPrintDocuments:			// sent when document is dragged onto printer
					AppleEventPrint( event );
					break;
					
				case kAEQuitApplication:		// sent from many locations (eg after restart command)
					QuitResKnife();
					break;
			}
			break;
		
/*		case kAECoreSuite:	// i'm not even registering for these yet
			switch( eventID )
			{
				case kAECut:
				case kAECopy:
				case kAEPaste:
				case kAEDelete:
					DisplayErrorDialog( "\pSorry, but cut, copy, paste and clear via Apple Events arn't yet supported." );
					error =  errAEEventNotHandled;
					break;
			}
			break;
*/	}
	return error;
}

  /******************/
 /* EVENT HANDLING */
/******************/

#if !TARGET_API_MAC_CARBON

/*** MOUSE DOWN EVENT OCCOURED ***/
OSStatus MouseDownEventOccoured( EventRecord *event )
{
	// get the window
	OSStatus	error = eventNotHandledErr;
	WindowRef	window;
	SInt16		windowPart = FindWindow( event->where, &window );
	WindowObjectPtr winObj = (WindowObjectPtr) GetWindowRefCon( window );
	
	// find out where the click occoured
	if( !windowPart ) return error;
	else switch( windowPart )
	{
		case inMenuBar:
			error = UpdateMenus( FrontWindow() );		// error ignored at the moment
			UInt32 menuChoice = MenuSelect( event->where );
			UInt16 menu = HiWord( menuChoice );
			UInt16 item = LoWord( menuChoice );
			error = ParseMenuSelection( menu, item );	// error ignored at the moment
			HiliteMenu( 0 );
			break;
			
		case inSysWindow:
			SystemClick( event, window );
			break;
			
		case inContent:
			SelectWindow( window );
			winObj->Click( event->where, event->modifiers );
			break;
			
		case inDrag:
			DragWindow( window, event->where, &qdb );
			winObj->BoundsChanged( null );
			break;
			
		case inGrow:
			Rect bounds;	// minimum and maximum bounds of window
			SetRect( &bounds, 128, 128, 1024, 1024 );
			SInt32 result = GrowWindow( window, event->where, &bounds );
			if( result )
			{
				SInt16 newWidth = LoWord( result );
				SInt16 newHeight = HiWord( result );
				SizeWindow( window, newWidth, newHeight, false );
				winObj->BoundsChanged( null );
			}
			break;
			
		case inGoAway:
			if( TrackGoAway( window, event->where ) )
				winObj->Close();
			break;
			
		case inZoomIn:
		case inZoomOut:
			if( TrackBox( window, event->where, windowPart ) )
			{
				ZoomWindow( window, windowPart, window == FrontWindow() );		// I think the last param *might* need to be "g.frontApp"
				winObj->BoundsChanged( null );
			}
			break;
		
		case inCollapseBox:
		case inProxyIcon:
			break;
	}
	return error;
}

/*** MOUSE UP EVENT OCCOURED ***/
OSStatus MouseUpEventOccoured( EventRecord *event )
{
	#pragma unused( event )
	OSStatus error = eventNotHandledErr;
	return error;
}

/*** KEY DOWN EVENT OCCOURED ***/
OSStatus KeyDownEventOccoured( EventRecord *event )
{
	OSStatus error = eventNotHandledErr;
	char key = (char)( event->message & charCodeMask );	// get the key pressed
	if( event->modifiers & cmdKey )						// was it a menu shortcut?
	{
		UpdateMenus( FrontWindow() );
		UInt32 menuChoice = MenuKey( key );
		UInt16 menu = HiWord( menuChoice );
		UInt16 item = LoWord( menuChoice );
		if( menu && item )
			error = ParseMenuSelection( menu, item );
	}
	return error;
}

/*** KEY REPEAT EVENT OCCOURED ***/
OSStatus KeyRepeatEventOccoured( EventRecord *event )
{
	OSStatus error = KeyDownEventOccoured( event );
	return error;
}

/*** KEY UP EVENT OCCOURED ***/
OSStatus KeyUpEventOccoured( EventRecord *event )
{
	#pragma unused( event )
	OSStatus error = eventNotHandledErr;
	return error;
}

/*** UPDATE EVENT OCCOURED ***/
OSStatus UpdateEventOccoured( EventRecord *event )
{
	OSStatus	error = eventNotHandledErr;
	GrafPtr		oldPort;
	WindowRef	window = (WindowRef) event->message;
	
	// send update events to window
	GetPort( &oldPort );
	SetPortWindowPort( window );
	BeginUpdate( window );	// this sets up the visRgn
	{
		RgnHandle updateRgn = NewRgn();
		WindowObjectPtr winObj = (WindowObjectPtr) GetWindowRefCon( window );
		GetPortVisibleRegion( GetWindowPort( window ), updateRgn );
		if( winObj ) error = winObj->Update( updateRgn );
		DisposeRgn( updateRgn );
	}
	EndUpdate( window );
	SetPort( oldPort );
	return error;
}

/*** ACTIVATE EVENT OCCOURED ***/
OSStatus ActivateEventOccoured( EventRecord *event )
{
	OSStatus error = eventNotHandledErr;
	WindowObjectPtr winObj = (WindowObjectPtr) GetWindowRefCon( (WindowRef) event->message );
	if( winObj ) error = winObj->Activate( (Boolean) (event->modifiers & activeFlag) );
	return error;
}

/*** IDLE EVENT ***/
OSStatus IdleEvent( void )
{
	// call sound idle routine
	if( g.asyncSound ) SHIdle();
	
	// compact all memory
/*	SInt32 total, contig;
	PurgeMem( kEmergencyMemory );
	CompactMem( kEmergencyMemory );
	PurgeSpace( &total, &contig );
	
	// deal with emergency memory
	if( total < kMinimumFreeMemory && g.emergencyMemory ) 
	{
		DisposeHandle( g.emergencyMemory );		// release emergence memory
		DisplayError( "\pMemory is running low, please close some windows." );
	}
	else if( !g.emergencyMemory && contig > kEmergencyMemory )	// try to recover handle if possible
		g.emergencyMemory = NewHandleClear( kEmergencyMemory );
*/	return noErr;
}

#endif

/*** QUIT RES KNIFE ***/
void QuitResKnife( void )
{
	// save all open files
	WindowRef window = FrontNonFloatingWindow(), nextWindow;
	while( window )
	{
		nextWindow = GetNextWindow( window );
		SInt32 kind = GetWindowKind( window );
		if( kind == kFileWindowKind )
		{
#if TARGET_API_MAC_CARBON
			EventRef event;
			CreateEvent( null, kEventClassWindow, kEventWindowClose, kEventDurationNoWait, kEventAttributeNone, &event );
			SendEventToWindow( event, window );
			ReleaseEvent( event );
#else
			// bug: this is totally the wrong thing to do here, but will have to do for now
			DisposeWindow( window );	// bug: windows don't close when sent a WindowClose event!
#endif
		}
		window = nextWindow;
	}
	
	if( !g.cancelQuit )
	{
		if( g.asyncSound )		SHKillSoundHelper();
		if( g.navAvailable )	NavUnload();
#if TARGET_API_MAC_CARBON
		QuitApplicationEventLoop();
#else
		g.quitting = true;
#endif
	}
}

  /*******************/
 /* MENU SELECTIONS */
/*******************/

#if TARGET_API_MAC_CARBON

/*** CARBON EVENT UPDATE MENUS ***/
pascal OSStatus CarbonEventUpdateMenus( EventHandlerCallRef callRef, EventRef event, void *userData )
{
	#pragma unused( callRef, event, userData )
	OSStatus error = eventNotHandledErr;
	Boolean fileOpen = (Boolean) FrontNonFloatingWindow();
	
	// application menu (passing null causes all menus to be searched)
	EnableCommand( null, kMenuCommandAbout, true );
	EnableCommand( null, kHICommandPreferences, true );
	
	// file menu
	EnableCommand( null, kMenuCommandNewFile, true );
	EnableCommand( null, kMenuCommandOpenFile, true );
	EnableCommand( null, kMenuCommandCloseWindow, fileOpen );
	EnableCommand( null, kMenuCommandCloseFile, fileOpen );
	EnableCommand( null, kMenuCommandSaveFile, fileOpen );	// bug: shoud be disabled if file is unmodified
	EnableCommand( null, kMenuCommandSaveFileAs, fileOpen );
	EnableCommand( null, kMenuCommandRevertFile, fileOpen );
	EnableCommand( null, kMenuCommandPageSetup, fileOpen );
	EnableCommand( null, kMenuCommandPrint, fileOpen );
	
/*	if( fileOpen )
	{
		// edit window
		EnableCommand( null, kHICommandUndo, false );
		EnableCommand( null, kHICommandRedo, false );
		EnableCommand( null, kHICommandCut, false );
		EnableCommand( null, kHICommandCopy, false );
		EnableCommand( null, kHICommandPaste, false );
		EnableCommand( null, kHICommandClear, false );
		EnableCommand( null, kHICommandSelectAll, false );
		EnableCommand( null, kMenuCommandFind, false );
		EnableCommand( null, kMenuCommandFindAgain, false );
		
		// resource menu
		EnableCommand( null, kMenuCommandNewResource, false );
		EnableCommand( null, kMenuCommandOpenHex, false );
		EnableCommand( null, kMenuCommandOpenDefault, false );
		EnableCommand( null, kMenuCommandOpenTemplate, false );
		EnableCommand( null, kMenuCommandOpenSpecific, false );
		EnableCommand( null, kMenuCommandRevertResource, false );
		EnableCommand( null, kMenuCommandPlaySound, false );
	}
*/	
	// debug menu
	EnableCommand( null, kMenuCommandDebug, true );
	EnableCommand( null, kMenuCommandAppleEvents, false );
	EnableCommand( null, kMenuCommandAppearance, false );
	EnableCommand( null, kMenuCommandNavServices, false );
	EnableCommand( null, kMenuCommandSheets, g.carbonVersion >= kCarbonLib11 );
	SetMenuCommandMark( null, kMenuCommandDebug,			g.debug?			kMenuCheckmarkGlyph : kMenuNullGlyph );
	SetMenuCommandMark( null, kMenuCommandSurpressErrors,	g.surpressErrors?	kMenuCheckmarkGlyph : kMenuNullGlyph );
	SetMenuCommandMark( null, kMenuCommandAppleEvents,		g.useAppleEvents?	kMenuCheckmarkGlyph : kMenuNullGlyph );	// these three should always be true in Carbon
	SetMenuCommandMark( null, kMenuCommandAppearance,		g.useAppearance?	kMenuCheckmarkGlyph : kMenuNullGlyph );
	SetMenuCommandMark( null, kMenuCommandNavServices,		g.useNavServices?	kMenuCheckmarkGlyph : kMenuNullGlyph );
	SetMenuCommandMark( null, kMenuCommandSheets,			g.useSheets?		kMenuCheckmarkGlyph : kMenuNullGlyph );
	
	return error;
}

/*** CARBON EVENT PARSE MENU SELECTION ***/
pascal OSStatus CarbonEventParseMenuSelection( EventHandlerCallRef callRef, EventRef event, void *userData )
{
	#pragma unused( callRef, userData )
	
	// get menu command
	HICommand menuCommand;
	OSStatus error = GetEventParameter( event, kEventParamDirectObject, typeHICommand, null, sizeof(HICommand), null, &menuCommand );
	if( error ) return eventNotHandledErr;
		
	switch( menuCommand.commandID )
	{
		// application menu
		case kMenuCommandAbout:
			ShowAboutBox();
			break;
		
		case kHICommandPreferences:
			ShowPrefsWindow();
			break;
		
		// file menu
		case kMenuCommandNewFile:
			new FileWindow;
			break;
		
		case kMenuCommandOpenFile:
			if( g.useSheets )	error = DisplayModelessGetFileDialog();
			else				error = DisplayOpenDialog();
			break;
				
		// debug menu
		case kMenuCommandDebug:
			g.debug = !g.debug;
			break;
		case kMenuCommandSurpressErrors:
			g.surpressErrors = !g.surpressErrors;
			break;
		case kMenuCommandAppleEvents:
			g.useAppleEvents = !g.useAppleEvents;
			break;
		case kMenuCommandAppearance:
			g.useAppearance = !g.useAppearance;
			break;
		case kMenuCommandNavServices:
			g.useNavServices = !g.useNavServices;
			break;
		case kMenuCommandSheets:
			g.useSheets = !g.useSheets;
			break;
		
		default:
			return eventNotHandledErr;	// pass all other events
	}
	
	return error;	// event handled here, so terminate.
}

/*** DEFAULT IDLE TIMER ***/
pascal void DefaultIdleTimer( EventLoopTimerRef timer, void *data )
{
	#pragma unused( timer, data )
	
	// idle controls (allow cursor blinking)
	IdleControls( GetUserFocusWindow() );	// bug: apple should have the control install it's own timer
	
	// call sound idle routine
	if( g.asyncSound && g.callSH ) SHIdle();
}

#else

/*** UPDATE MENUS ***/
OSStatus UpdateMenus( WindowRef window )
{
	#pragma unused( window )
	OSStatus error = noErr;
	
	// disable/checkmark items in the debug menu
	MenuRef debugMenu = GetMenuRef( kDebugMenu );
	MenuItemEnable( debugMenu, kDebugMenuAppearanceItem, g.appearanceAvailable );
	MenuItemEnable( debugMenu, kDebugMenuNavServicesItem, g.navAvailable );
	MenuItemEnable( debugMenu, kDebugMenuSheetsItem, false );
	CheckMenuItem( debugMenu, kDebugMenuDebugItem, g.debug );
	CheckMenuItem( debugMenu, kDebugMenuSurpressErrorsItem, g.surpressErrors );
	CheckMenuItem( debugMenu, kDebugMenuAppleEventsItem, g.useAppleEvents );
	CheckMenuItem( debugMenu, kDebugMenuAppearanceItem, g.useAppearance );
	CheckMenuItem( debugMenu, kDebugMenuNavServicesItem, g.useNavServices );
	
	return error;
}

/*** PARSE MENU SELECTION ***/
OSStatus ParseMenuSelection( UInt16 menu, UInt16 item )
{
	// get the frontmost window, in all it's various forms
	OSStatus error = eventNotHandledErr;
	WindowRef window = FrontWindow();
	WindowObjectPtr winObj = null;
	FileWindowPtr file = null;
	if( window )
	{
		winObj = (WindowObjectPtr) GetWindowRefCon( window );
		if( GetWindowKind( window ) == kFileWindowKind )
			file = (FileWindowPtr) winObj;
	}
	
	// do the menu function
	if( menu && item )
	{
		switch( menu )
		{
			case kAppleMenu:
				switch( item )
				{
					case kAppleMenuAboutItem:
						ShowAboutBox();
						break;
					
					default:	// something from "apple menu items" folder
						Str255 itemName;
						MenuHandle appleMenu = GetMenuHandle( kAppleMenu );
						GetMenuItemText( appleMenu, item, itemName );
						OpenDeskAcc( itemName );
						break;
				}
				break;
			
			case kFileMenu:
				switch( item )
				{
					case kFileMenuNewFileItem:
						new FileWindow;
						break;
					
					case kFileMenuOpenFileItem:
						if( g.useNavServices )	DisplayOpenDialog();
						else					DisplayStandardFileOpenDialog();
						break;
					
					case kFileMenuCloseWindowItem:
						if( winObj ) winObj->Close();
						break;
					
					case kFileMenuQuitItem:
						AEDescList list = {};
						error = AppleEventSendSelf( kCoreEventClass, kAEQuitApplication, list );
						if( error ) QuitResKnife();
						break;
				}
				break;
			
			case kEditMenu:
/*				switch( item )
				{
					case :
						break;
				}
*/				break;
			
			case kResourceMenu:
				switch( item )
				{
					case kResourceMenuNewResource:
						if( file ) file->DisplayNewResourceDialog();
						break;
				}
				break;
			
			case kDebugMenu:
				switch( item )
				{
					case kDebugMenuDebugItem:
						g.debug = !g.debug;
						break;
					
					case kDebugMenuSurpressErrorsItem:
						g.surpressErrors = !g.surpressErrors;
						break;
					
					case kDebugMenuAppleEventsItem:
						g.useAppleEvents = !g.useAppleEvents;
						break;
					
					case kDebugMenuAppearanceItem:
						g.useAppearance = !g.useAppearance;
						break;
					
					case kDebugMenuNavServicesItem:
						g.useNavServices = !g.useNavServices;
						break;
				}
				break;
		}
		error = UpdateMenus( FrontWindow() );
	}
	return error;
}

#endif

  /****************/
 /* APPLE EVENTS */
/****************/

/*** SEND MYSELF AN APPLE EVENT ***/
OSStatus AppleEventSendSelf( DescType eventClass, DescType eventID, AEDescList list )
{
	OSStatus		error;
	AEAddressDesc	myAddress;			// all of these are really of type AEDesc
	AppleEvent		noReply;
	AppleEvent		event;
	
	myAddress.descriptorType	= typeNull;
	myAddress.dataHandle		= null;
	noReply.descriptorType		= typeNull;
	noReply.dataHandle			= null;

	ProcessSerialNumber psn;
	error = GetCurrentProcess( &psn );
	if( error ) return error;
	
	error = AECreateDesc( typeProcessSerialNumber, &psn, sizeof(ProcessSerialNumber), &myAddress );
	if( error ) return error;
	
	error = AECreateAppleEvent( eventClass, eventID, &myAddress, kAutoGenerateReturnID, kAnyTransactionID, &event );
	if( error ) return error;
	
	error = AEPutParamDesc( &event, keyDirectObject, &list );
	if( error ) return error;
	
	error = AESend( &event, &noReply, kAENoReply, kAENormalPriority, kAEDefaultTimeout, null, null );
	return error;
}

/*** GOT REQUIRED PARAMS ***/
Boolean GotRequiredParams( const AppleEvent *event )
{
	OSStatus	error = noErr;
	DescType	actualType;
	Size		actualSize;
	
	// check if we have retreived the required parameters
	error = AEGetAttributePtr( event, keyMissedKeywordAttr, typeWildCard, &actualType, null, 0, &actualSize );
	return error == errAEDescNotFound;
}

/*** OPEN ***/
OSStatus AppleEventOpen( const AppleEvent *event )
{
	OSStatus error = noErr;
	
	// get the list of objects to open
	AEDescList	list;
	AEKeyword	aeKeyword;
	aeKeyword = keyDirectObject;
	error = AEGetParamDesc( event, aeKeyword, typeAEList, &list );
	if( !GotRequiredParams( event ) || error ) return errAEEventNotHandled;
	
	// count how many we have
	SInt32 itemCount;
	error = AECountItems( &list, &itemCount );
	if( error ) return errAEEventNotHandled;
	
	// open each one
	FSSpec		fileSpec;
	DescType	actualType;
	Size		actualSize;
	for( SInt32 n = 1; n <= itemCount; n++ )
	{
		error = AEGetNthPtr( &list, n, typeFSS, &aeKeyword, &actualType, (Ptr) &fileSpec, sizeof(FSSpec), &actualSize );
		if( actualType == typeFSS && !error ) new FileWindow( &fileSpec );
	}
	
	AEDisposeDesc( &list );
	return error;
}

/*** PRINT ***/
OSStatus AppleEventPrint( const AppleEvent *event )
{
	#pragma unused( event )
	return errAEEventNotHandled;
}

  /************************/
 /* NIB WINDOW MANAGMENT */
/************************/

/*** SHOW ABOUT BOX ***/
OSStatus ShowAboutBox( void )
{
#if TARGET_API_MAC_CARBON
#if USE_NIBS
	// create a nib reference (only searches the application bundle)
	IBNibRef nibRef = null;
	OSStatus error = CreateNibReference( CFSTR("ResKnife"), &nibRef );
	if( error != noErr || nibRef == null )
	{
		DisplayError( "\pThe nib file reference could not be obtained." );
		return error;
	}
	
	// create window
	WindowRef window;
	error = CreateWindowFromNib( nibRef, CFSTR("About Box"), &window );
	if( error != noErr || window == null )
	{
		DisplayError( "\pThe about box could not be obtained from the nib file." );
		return error;
	}
	
	// dispose of nib ref
	DisposeNibReference( nibRef );
	
	// show window
	ShowWindow( window );
#else
	Rect creationBounds;
	WindowRef window;
	SetRect( &creationBounds, 0, 0, 300, 300 );
	OffsetRect( &creationBounds, 50, 50 );
	OSStatus error = CreateNewWindow( kDocumentWindowClass, kWindowStandardDocumentAttributes | kWindowStandardHandlerAttribute | kWindowInWindowMenuAttribute, &creationBounds, &window );
	
	ControlRef picControl;
	ControlButtonContentInfo content;
/*	content.contentType = kControlContentPictHandle;
	content.u.picture = GetPicture( 128 );
	if( content.u.picture == null ) DebugStr("\ppicture == null");
*/	content.contentType = kControlContentPictRes;
	content.u.resID = 128;
	CreatePictureControl( window, &creationBounds, &content, true, &picControl );
//	SetControlData( picControl, kControlPicturePart, kControlPictureHandleTag, sizeof(content.u.picture), content.u.picture );
#endif
#else
	WindowRef window = null;
	if( g.useAppearance && g.systemVersion >= kMacOS8 )
		window = GetNewCWindow( kFileWindow8, null, kFirstWindowOfClass );
	else
		window = GetNewCWindow( kFileWindow7, null, kFirstWindowOfClass );
	if( window == null ) return paramErr;
	PicHandle picture = (PicHandle) GetPicture( 128 );
	SetWindowPic( window, picture );
#endif
	
	ShowWindow( window );
	return noErr;
}

/*** SHOW PREFERENCES WINDOW ***/
OSStatus ShowPrefsWindow( void )
{
#if USE_NIBS
	// create a nib reference (only searches the application bundle)
	IBNibRef nibRef = null;
	OSStatus error = CreateNibReference( CFSTR("ResKnife"), &nibRef );
	if( error != noErr || nibRef == null )
	{
		DisplayError( "\pThe nib file reference could not be obtained." );
		return error;
	}
	
	// create window
	WindowRef window;
	error = CreateWindowFromNib( nibRef, CFSTR("Preferences"), &window );
	if( error != noErr || window == null )
	{
		DisplayError( "\pThe preferences window could not be obtained from the nib file." );
		return error;
	}
	
	// dispose of nib ref
	DisposeNibReference( nibRef );
	
	// install tabs handler
	ControlRef control;
	ControlID id = { 'tabs', 1 };
	GetControlByID( window, &id, &control );
	EventTypeSpec event = { kEventClassControl, kEventControlHit };
	InstallEventHandler( GetControlEventTarget(control), NewEventHandlerUPP( PrefsTabEventHandler ), 1, &event, &control, null );
	
	// show window
	ShowWindow( window );
#endif
	return noErr;
}

/*** PREFS TAB EVENT HANDLER ***/
pascal OSStatus PrefsTabEventHandler( EventHandlerCallRef handlerRef, EventRef event, void* userData )
{
	#pragma unused( handlerRef, event )
	
	// get tabs control
	OSStatus error = noErr;
	ControlRef control = (ControlRef) userData;
	SInt16 selectedTab = GetControlValue( control );
	WindowRef window = GetControlOwner( control );
	
	// select correct tab
	ControlRef currentTab;
	ControlID id = { 'pane', 1 };
	GetControlByID( window, &id, &currentTab );
	SetControlVisibility( currentTab, selectedTab == id.id, true );
	id.id = 2;
	GetControlByID( window, &id, &currentTab );
	SetControlVisibility( currentTab, selectedTab == id.id, true );
	
	return error;
}
