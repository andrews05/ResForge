#include "InspectorWindow.h"
#include "FileWindow.h"
#include "ResourceObject.h"
#include "Utility.h"
extern globals g;

  /*******************/
 /* WINDOW & EVENTS */
/*******************/

/*** CONSTRUCTOR ***/
InspectorWindow::InspectorWindow( void )
{
	// if inspector already exists, return
	if( g.inspector )
	{
		SelectWindow( g.inspector->Window() );
		return;
	}
	
#if TARGET_API_MAC_CARBON
	// create window
	Str255 windowName;
	Rect creationBounds;
	SetRect( &creationBounds, 0, 0, kInspectorWindowWidth, kInspectorWindowHeight );
	OffsetRect( &creationBounds, 520, 45 );
	OSStatus error = CreateNewWindow( kFloatingWindowClass, kWindowStandardFloatingAttributes | kWindowStandardHandlerAttribute, &creationBounds, &window );
	GetIndString( windowName, kWindowNameStrings, kStringInspectorWindowName );
	SetWindowTitle( window, windowName );
	SetWindowKind( window, kInspectorWindowKind );
	SetThemeWindowBackground( window, kThemeBrushUtilityWindowBackgroundActive, false );

	// install window event handler
	EventHandlerRef	ref			= null;
	EventHandlerUPP	eventHandler = NewEventHandlerUPP( CloseInspectorWindow );
	EventTypeSpec	events[]	= {	{ kEventClassWindow, kEventWindowClose } };
	InstallWindowEventHandler( window, eventHandler, GetEventTypeCount(events), (EventTypeSpec *) &events, this, &ref );
	
	// create root control
	Rect bounds;
	if( g.systemVersion < kMacOSX )
	{
		ControlRef root;
		CreateRootControl( window, &root );
	}
	
	// create image well
	ControlRef imageWell;
	ControlButtonContentInfo content;
	content.contentType = kControlNoContent;
	SetRect( &bounds, 0, 0, 44, 44 );
	OffsetRect( &bounds, 8, 8 );
	CreateImageWellControl( window, &bounds, &content, &imageWell );
	
	// create static text controls
	Rect windowRect;
	ControlRef name, type, id;
	ControlFontStyleRec fontStyle;
	fontStyle.flags = kControlUseFontMask + kControlUseJustMask;
	fontStyle.font = kControlFontSmallSystemFont;
	fontStyle.just = teJustLeft;
	GetWindowPortBounds( window, &windowRect );
	SetRect( &bounds, windowRect.left +60, windowRect.top +8, windowRect.right - windowRect.left -8, windowRect.top +36 );
	CreateStaticTextControl( window, &bounds, CFSTR(""), &fontStyle, &name );
	fontStyle.font = kControlFontSmallBoldSystemFont;
	SetRect( &bounds, windowRect.left +60, windowRect.top +38, windowRect.right - windowRect.left -70, windowRect.top +52 );
	CreateStaticTextControl( window, &bounds, CFSTR(""), &fontStyle, &type );
	SetRect( &bounds, windowRect.right - windowRect.left -70, windowRect.top +38, windowRect.right - windowRect.left -8, windowRect.top +52 );
	CreateStaticTextControl( window, &bounds, CFSTR(""), &fontStyle, &id );
	
	// create group control
	ControlRef group;
	GetWindowPortBounds( window, &bounds );
	InsetRect( &bounds, 8, 8 );
	bounds.top += kInspectorHeaderHeight;
	CreateGroupBoxControl( window, &bounds, CFSTR("Attributes"), true, &group );
	
	// create checkboxes
	ControlRef changedBox, preloadBox, protectedBox,
				lockedBox, purgeableBox, sysHeapBox;
	InsetRect( &bounds, 4, 4 );
	bounds.top	= bounds.bottom - kControlCheckBoxHeight;
	CreateCheckBoxControl( window, &bounds, CFSTR("System Heap"), kControlCheckBoxUncheckedValue, true, &sysHeapBox );
	bounds.top		-= kControlCheckBoxHeight;
	bounds.bottom	-= kControlCheckBoxHeight;
	CreateCheckBoxControl( window, &bounds, CFSTR("Purgeable"), kControlCheckBoxUncheckedValue, true, &purgeableBox );
	bounds.top		-= kControlCheckBoxHeight;
	bounds.bottom	-= kControlCheckBoxHeight;
	CreateCheckBoxControl( window, &bounds, CFSTR("Locked"), kControlCheckBoxUncheckedValue, true, &lockedBox );
	bounds.top		-= kControlCheckBoxHeight;
	bounds.bottom	-= kControlCheckBoxHeight;
	CreateCheckBoxControl( window, &bounds, CFSTR("Protected"), kControlCheckBoxUncheckedValue, true, &protectedBox );
	bounds.top		-= kControlCheckBoxHeight;
	bounds.bottom	-= kControlCheckBoxHeight;
	CreateCheckBoxControl( window, &bounds, CFSTR("Preload"), kControlCheckBoxUncheckedValue, true, &preloadBox );
	bounds.top		-= kControlCheckBoxHeight;
	bounds.bottom	-= kControlCheckBoxHeight;
	CreateCheckBoxControl( window, &bounds, CFSTR("Changed"), kControlCheckBoxUncheckedValue, true, &changedBox );
	
	// embed controls
	EmbedControl( changedBox, group );
	EmbedControl( preloadBox, group );
	EmbedControl( protectedBox, group );
	EmbedControl( lockedBox, group );
	EmbedControl( purgeableBox, group );
	EmbedControl( sysHeapBox, group );
#else
	if( g.useAppearance && g.systemVersion >= kMacOSEight )
		window = GetNewCWindow( kFileWindow8, null, kFirstWindowOfClass );
	else
		window = GetNewCWindow( kFileWindow7, null, kFirstWindowOfClass );
#endif
	
	// update and show window
	Update();
	ShowWindow( window );
	g.inspector = this;
}

/*** DESTRUCTOR ***/
InspectorWindow::~InspectorWindow( void )
{
	g.inspector = null;
}

/*** CLOSW WINDOW EVENT HANDLER ***/
pascal OSStatus CloseInspectorWindow( EventHandlerCallRef callRef, EventRef event, void *userData )
{
	#pragma unused( callRef, event, userData )
	if( g.inspector ) delete g.inspector;
	return eventNotHandledErr;
}

/*** UPDATE WINDOW ***/
OSStatus InspectorWindow::Update( RgnHandle region )
{
	#pragma unused( region )
#if TARGET_API_MAC_CARBON
	// get target file
	FileWindowPtr file = null;
	WindowRef fileWindow = GetFrontWindowOfClass( kDocumentWindowClass, true );
	if( !fileWindow ) return noErr;	// no window is open - BUG: items in window are not cleared
	
	OSStatus error = noErr;
	Boolean validWindow = false;
	while( !validWindow || error )
	{
		WindowKind kind = (WindowKind) GetWindowKind( fileWindow );
		if( kind != kFileWindowKind )
		{
			fileWindow = GetNextWindowOfClass( fileWindow, kDocumentWindowClass, true );
			if( !window ) error = paramErr;
		}
		else
		{
			file = (FileWindowPtr) GetWindowRefCon( fileWindow );
			if( file ) validWindow = true;
			else error = paramErr;
		}
	}
	if( error ) return error;
	
	// get selection
	UInt32 itemCount;
	ControlRef browser = null;
	GetWindowProperty( fileWindow, kResKnifeCreator, kDataBrowserSignature, sizeof(ControlRef), null, &browser );
	GetDataBrowserItemCount( browser, kDataBrowserNoItem, true, kDataBrowserItemIsSelected, &itemCount );
	
	// get controls
	ControlRef root, well, name, type, id, group;
	ControlRef changedBox, preloadBox, protectedBox, lockedBox, purgeableBox, sysHeapBox;
	ControlButtonContentInfo content;
	GetRootControl( window, &root );
	GetIndexedSubControl( root, 1, &well );
	GetIndexedSubControl( root, 2, &name );
	GetIndexedSubControl( root, 3, &type );
	GetIndexedSubControl( root, 4, &id );
	GetIndexedSubControl( root, 5, &group );
	GetIndexedSubControl( group, 1, &changedBox );
	GetIndexedSubControl( group, 2, &preloadBox );
	GetIndexedSubControl( group, 3, &protectedBox );
	GetIndexedSubControl( group, 4, &lockedBox );
	GetIndexedSubControl( group, 5, &purgeableBox );
	GetIndexedSubControl( group, 6, &sysHeapBox );
	
	if( itemCount != 1 )
	{
		// set icon
		content.contentType = kControlNoContent;
		SetImageWellContentInfo( well, &content );
		DrawOneControl( well );	// bug: work around for bug in ControlManager
//		DisableControl( well );
		
		// set name
		StringPtr blank = (StringPtr) NewPtrClear( sizeof(Str255) );
		CopyPascalStringToC( "\p", (char *) blank );
		SetControlData( name, kControlLabelPart, kControlStaticTextTextTag, 1, blank );
		SetControlTitle( name, "\p" );
		
		// set type
		SetControlData( type, kControlLabelPart, kControlStaticTextTextTag, 1, blank );
		SetControlTitle( type, "\p" );
		
		// set ID
		SetControlData( id, kControlLabelPart, kControlStaticTextTextTag, 1, blank );
		SetControlTitle( id, "\p" );
		
		// set control values
		SetControlValue( changedBox,	kControlCheckBoxUncheckedValue );
		SetControlValue( preloadBox,	kControlCheckBoxUncheckedValue );
		SetControlValue( protectedBox,	kControlCheckBoxUncheckedValue );
		SetControlValue( lockedBox,		kControlCheckBoxUncheckedValue );
		SetControlValue( purgeableBox,	kControlCheckBoxUncheckedValue );
		SetControlValue( sysHeapBox,	kControlCheckBoxUncheckedValue );
//		DisableControl( group );
	}
	else
	{
		// get selected resource 
		DataBrowserItemID first, last;
		GetDataBrowserSelectionAnchor( browser, &first, &last );	// first must == last
		ResourceObjectPtr resource = file->GetResource(first);
		
		// set icon
		content.contentType = kControlContentIconSuiteRes;
		content.u.resID = kDefaultResourceIcon;
		SetImageWellContentInfo( well, &content );
		DrawOneControl( well );	// bug: work around for bug in ControlManager
//		EnableControl( well );
		
		// set name
		StringPtr label = (StringPtr) NewPtrClear( sizeof(Str255) );
		if( PStringLength( resource->Name()) == 0 )	GetIndString( label, kResourceNameStrings, kStringUntitledResource );
		else										CopyPascalStringToC( resource->Name(), (char *) label );
		SetControlData( name, kControlLabelPart, kControlStaticTextTextTag, PStringLength(resource->Name()), label );
		SetControlTitle( name, resource->Name() );
		
		// set type
		Str255 string;
		TypeToPString( resource->Type(), string );
		CopyPascalStringToC( string, (char *) label );
		SetControlData( type, kControlLabelPart, kControlStaticTextTextTag, string[0], label );
		SetControlTitle( type, string );
		
		// set ID
		NumToString( resource->ID(), string );
		CopyPascalStringToC( string, (char *) label );
		SetControlData( id, kControlLabelPart, kControlStaticTextTextTag, string[0], label );
		SetControlTitle( id, string );
		
		// set control values
		SetControlValue( changedBox,	(resource->Attributes() & resChanged)?		kControlCheckBoxCheckedValue : kControlCheckBoxUncheckedValue );
		SetControlValue( preloadBox,	(resource->Attributes() & resPreload)?		kControlCheckBoxCheckedValue : kControlCheckBoxUncheckedValue );
		SetControlValue( protectedBox,	(resource->Attributes() & resProtected)?	kControlCheckBoxCheckedValue : kControlCheckBoxUncheckedValue );
		SetControlValue( lockedBox,		(resource->Attributes() & resLocked)?		kControlCheckBoxCheckedValue : kControlCheckBoxUncheckedValue );
		SetControlValue( purgeableBox,	(resource->Attributes() & resPurgeable)?	kControlCheckBoxCheckedValue : kControlCheckBoxUncheckedValue );
		SetControlValue( sysHeapBox,	(resource->Attributes() & resSysHeap)?		kControlCheckBoxCheckedValue : kControlCheckBoxUncheckedValue );
		DeactivateControl( changedBox );
//		EnableControl( group );
	}
	return error;
#else
	return noErr;
#endif
}