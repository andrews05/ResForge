#include "HexWindow.h"
#include "Events.h"
#include "stdio.h"
// #include "strings.h"

extern globals g;
extern prefs p;

/*** CREATOR ***/
HexWindow::HexWindow( WindowRef newWindow )
{
	// set contents to zero
	memset( this, 0, sizeof(HexWindow) );
	
	// initalise the bits that need initalising
	window = newWindow;
#if USE_NIBS
	// load stuff from nib file
#elif TARGET_API_MAC_CARBON
	// create root control
	ControlRef root;
	CreateRootControl( window, &root );
	
	// create header
	header = null;
	left = null;
	right = null;
	
	// create scroll bar
	Rect windowBounds;
	ControlActionUPP liveTrackingProc = NewControlActionUPP( TrackScrollbar );
	GetWindowPortBounds( window, &windowBounds );
	windowBounds.top	+= kHeaderHeight -1;
	windowBounds.bottom	-= kScrollBarWidth -2;
	windowBounds.left	= windowBounds.right - kScrollBarWidth +1;
	windowBounds.right	+= 1;
	CreateScrollBarControl( window, &windowBounds, 0, 0, 0, 0, true, liveTrackingProc, &scrollbar );
	
	ControlID id = { kScrollbarSignature, 0 };
	SetControlID( scrollbar, &id );
#else
	// only create a scroll bar
	scrollbar = GetNewControl( kSystem7ScrollBarControl, window );
#endif
}

/*** DESTRUCTOR ***/
HexWindow::~HexWindow( void )
{
//	Host_ReleaseResourceData( hexInfo->data );	// decreases refCount
	RemoveEventLoopTimer( timer );
	DisposeControl( scrollbar );
}

  /**********/
 /* EVENTS */
/**********/

/*** BOUNDS CHANGING ***/
OSStatus HexWindow::BoundsChanging( EventRef event )
{
	OSStatus error = noErr;
#if TARGET_API_MAC_CARBON
	// check that window is not just being dragged
	UInt32 attributes;
	error = GetEventParameter( event, kEventParamAttributes, typeUInt32, null, sizeof(UInt32), null, &attributes );
	if( error || attributes & kWindowBoundsChangeUserDrag ) return eventNotHandledErr;
	
	// get new bounds
	Rect windowBounds;
	error = GetEventParameter( event, kEventParamCurrentBounds, typeQDRectangle, null, sizeof(Rect), null, &windowBounds );
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
	if( g.systemVersion < kMacOSX ) return noErr;
	error = BoundsChanged( event );
#endif
	return error;
}

/*** BOUNDS CHANGED ***/
OSStatus HexWindow::BoundsChanged( EventRef event )
{
	Rect windowBounds;
	OSStatus error = GetEventParameter( event, kEventParamCurrentBounds, typeQDRectangle, null, sizeof(Rect), null, &windowBounds );
	if( error ) return eventNotHandledErr;
	
#if TARGET_API_MAC_CARBON
	// resize header
	SizeControl( header, (windowBounds.right - windowBounds.left) +2, kHeaderHeight +1 );
	SizeControl( left, (windowBounds.right - windowBounds.left) /2 -4, kHeaderHeight -4 );
	SizeControl( right, (windowBounds.right - windowBounds.left) /2 -4, kHeaderHeight -4 );
	MoveControl( right, (windowBounds.right - windowBounds.left) /2, 2 );
#endif
	
	// resize scrollbar
	MoveControl( scrollbar, (windowBounds.right - windowBounds.left) - kScrollBarWidth +1, kHeaderHeight -1 );
	SizeControl( scrollbar, kScrollBarWidth, (windowBounds.bottom - windowBounds.top) - kHeaderHeight - kScrollBarWidth +3 );
	
	// calculate new scrollbar values & redraw window
	UpdateHexInfo();
	InvalidateWindowRect( window, &windowBounds );
	
	EventRef updateEvent;
	error = CreateEvent( null, kEventClassWindow, kEventWindowUpdate, GetCurrentEventTime(), 0, &updateEvent );
	if( error == noErr )
	{
		SetEventParameter( updateEvent, kEventParamDirectObject, typeWindowRef, sizeof(WindowRef), &window );
		SendEventToWindow( updateEvent, window );
		ReleaseEvent( updateEvent );
	}
	return noErr;
}

/*** CONTENT CLICK ***/
OSStatus HexWindow::ContentClick( EventRef event )
{
	#pragma unused( event )
	return eventNotHandledErr;
}

/*** DRAW CONTENT ***/
OSStatus HexWindow::DrawContent( EventRef event )
{
	#pragma unused( event )	// could be null if I called this directly, therefore I ignore the param
	
	// set window
	GrafPtr oldPort;
	GetPort( &oldPort );
	SetPortWindowPort( window );
	
	// initalise rects
	RGBColour colour;
	Rect windowBounds, drawingBounds;
	GetWindowPortBounds( window, &windowBounds );
	SetRect( &drawingBounds, windowBounds.left,  windowBounds.top + kHeaderHeight, windowBounds.right - kScrollBarWidth +1, windowBounds.bottom );
	SetRect( &hexRect, kHexCharWidth *11 -3, kTextMargin + kHeaderHeight, kHexCharWidth *58 +3, windowBounds.bottom - kTextMargin );
	SetRect( &asciiRect, kHexCharWidth *60 -3, kTextMargin + kHeaderHeight, kHexCharWidth *76 +3, windowBounds.bottom - kTextMargin );
	
#if Use_GWorlds
	CGrafPtr		origPort;
	GDHandle		origDev;
	GWorldPtr		theGWorld;
	PixMapHandle	thePixMap;
	
	// create GWorld
	GetGWorld( &origPort, &origDev );
		//	( storage, bit depth, rect, colour table, GDevice, option flags )		// bit depth 0 = screen depth
	NewGWorld( &theGWorld, p.GWorldDepth, &drawingBounds, null, null, 0 );
	if( !theGWorld )
	{
		Host_DebugError( "\pNewGWorld() failed", 0 );
		return eventNotHandledErr;
	}
	SetGWorld( theGWorld, null );
	thePixMap = GetGWorldPixMap( theGWorld );
	
	// lock the pixelmap in place
	Boolean pixelsLocked = LockPixels( thePixMap );
	if( !pixelsLocked )
	{
		UpdateGWorld( &theGWorld, 0, &drawingBounds, null, null, 0 );
		pixelsLocked = LockPixels( thePixMap );
		if( !pixelsLocked )		// if I still can't lock the damn pixels, give up! (don't even attempt writing to a moving target :)
		{
			SetGWorld( origPort, origDev );
			DisposeGWorld( theGWorld );
			Host_DebugError( "\pUpdateGWorld() failed", 0 );
			return eventNotHandledErr;
		}
	}
#endif
	
	// set font
	short font;
	GetFNum( "\pCourier", &font );
	TextFont( font );
	TextFace( 0 );
	TextSize( 12 );
	PenNormal();
	
	// clear the background
	RGBBackColor( &g.bgColour );
	EraseRect( &drawingBounds );
	
	// set text colour
	if( activeWindow )
			colour = g.black;
	else	colour = g.textColour;
	RGBForeColor( &colour );
	
	// draw box around hex
	RGBBackColor( &g.white );
	EraseRect( &hexRect );
	FrameRect( &hexRect );
	if( activeWindow && p.GWorldDepth > 1 )
	{
		RGBForeColor( &g.white );
		MoveTo( hexRect.left,		hexRect.bottom );
		LineTo( hexRect.right,		hexRect.bottom );
		LineTo( hexRect.right,		hexRect.top );
		RGBForeColor( &g.bevelColour );
		MoveTo( hexRect.right,		hexRect.top -1 );
		LineTo( hexRect.left -1,	hexRect.top -1 );
		LineTo( hexRect.left -1,	hexRect.bottom );
	}
	
	// draw box around ascii
	RGBForeColor( &colour );
	RGBBackColor( &g.white );
	EraseRect( &asciiRect );
	FrameRect( &asciiRect );
	if( activeWindow && p.GWorldDepth > 1 )
	{
		RGBForeColor( &g.white );
		MoveTo( asciiRect.left,	asciiRect.bottom );
		LineTo( asciiRect.right,	asciiRect.bottom );
		LineTo( asciiRect.right,	asciiRect.top );
		RGBForeColor( &g.bevelColour );
		MoveTo( asciiRect.right,	asciiRect.top -1 );
		LineTo( asciiRect.left -1,	asciiRect.top -1 );
		LineTo( asciiRect.left -1,	asciiRect.bottom );
	}
	
	// hilight where selected text will be
	if( selStart != selEnd )
	{
		// get regions of selected text
		RgnHandle hexRgn = NewRgn(), asciiRgn = NewRgn(), insetRgn = NewRgn();
		FindSelectedRegions( window, hexRgn, asciiRgn );
		
		// set foreground colour to hilight colour
		RGBColour hilightColour;
		GetPortHilightColour( GetWindowPort(window), &hilightColour );
		RGBForeColor( &hilightColour );
		
		// draw what needs to be drawn
		PenSize( 2, 2 );
		if( editingHex )	PaintRgn( hexRgn );
		else				FrameRgn( hexRgn );
		if( !editingHex )	PaintRgn( asciiRgn );
		else				FrameRgn( asciiRgn );
		PenNormal();
		
		DisposeRgn( hexRgn );
		DisposeRgn( asciiRgn );
		DisposeRgn( insetRgn );
	}
		
	// reset text colour
	if( activeWindow )
			colour = g.black;
	else	colour = g.textColour;
	RGBForeColor( &colour );
	
	// get useful data
	Plug_WindowRef plugWindow = Host_GetPlugWindowFromWindowRef( window );
	Plug_ResourceRef resource = Host_GetTargetResource( plugWindow );
	
	// get resource length & lock data handle
	UInt32 length = Host_GetResourceSize( resource );	// which of these two would be faster?
//	UInt32 length = GetHandleSize( data );				//	the host callback returns a value from a struct, GetHandleSize probably does the same
	HLock( data );
	if( Host_GetResourceSize( resource ) != GetHandleSize( data ) )
	{
		SetGWorld( origPort, origDev );
		Host_DebugError( "\presource size != handle size", Host_GetResourceSize( resource ) );	// would be nice if I could pass both values! (any one know how to convert a number to > 1?  -  i.e. use "12.34" to pass 12 and 34)
		SetGWorld( theGWorld, null );
	}
	
	// init variables
	char	buffer[16*4 +11];
	long	addr;						// offset of byte in current res chunk
	UInt32	line,						// current line number
			currentByte	= topline *16;	// offset of byte in resource
	short	hexPos, asciiPos;
	unsigned char	ascii, hex1, hex2;	// HexEdit uses 'register short' not 'unsigned char' ?!?!
	
	// start line count at scroll value
	for( line = topline; line <= (lastline < bottomline? lastline:bottomline); line++ )	
	{
		hexPos = 10;
		asciiPos = 59;
		sprintf( buffer, "%08lX: ", currentByte );
		
		// draw bytes
		for( addr = 0; addr < 16; addr++ )
		{
			if( currentByte < length )
			{
				BlockMoveData( *data + currentByte, &ascii, 1 );
				hex1 = ascii;
				hex2 = ascii;
				hex1 >>= 4;
				hex1 &= 0x0F;
				hex2 &= 0x0F;
				hex1 += (hex1 < 10)? 0x30 : 0x37;
				hex2 += (hex2 < 10)? 0x30 : 0x37;
				
				buffer[hexPos++] = hex1;
				buffer[hexPos++] = hex2;
				buffer[hexPos++] = 0x20;
				if( ascii >= p.lowChar && ascii < p.highChar )
					 buffer[asciiPos++] = ascii;
				else buffer[asciiPos++] = 0x2E;	// full stop								
			}
			else
			{
				// without this the ascii would be printed right next to the hex on the last line
				buffer[hexPos++] = 0x20;
				buffer[hexPos++] = 0x20;
				buffer[hexPos++] = 0x20;
				buffer[asciiPos++] = 0x20;
			}
			
			// fill hex/ascii gap with a space to make it print
			buffer[58] = 0x20;
			
			// advance current byte
			currentByte++;
		}
		
		MoveTo( kHexCharWidth, kHeaderHeight + kTextMargin + kHexLineHeight*(line - topline +1) );
		DrawText( buffer, 0, 75 );	// buffer, first byte, byte count
	}
	
	// unlock handle and record window heights
	HUnlock( data );
	
#if Use_GWorlds
	SetGWorld( origPort, origDev );
	RGBBackColor( &g.white );
	RGBForeColor( &g.black );
	CopyBits( GetPortBitMapForCopyBits(theGWorld), GetPortBitMapForCopyBits(GetWindowPort(window)), &drawingBounds /*source rect*/, &drawingBounds /*dest rect*/, srcCopy, null );
	UnlockPixels( thePixMap );		// line redundant as GWorld is disposed of next!
	DisposeGWorld( theGWorld );
#endif
	
	// restore old port
	SetPort( oldPort );
	return eventNotHandledErr;
}

  /****************/
 /* MAINTAINANCE */
/****************/

/*** UPDATE HEX INFO ***/
OSStatus HexWindow::UpdateHexInfo( void )
{
	// hex and ascii rects
	Rect windowBounds;
	GetWindowPortBounds( window, &windowBounds );
	SetRect( &hexRect, kHexCharWidth *11 -3, kTextMargin + kHeaderHeight, kHexCharWidth *58 +3, windowBounds.bottom - kTextMargin );
	SetRect( &asciiRect, kHexCharWidth *60 -3, kTextMargin + kHeaderHeight, kHexCharWidth *76 +3, windowBounds.bottom - kTextMargin );
	
	// scrollbar globals
	firstline	= 0;
	topline		= GetControlValue( scrollbar );
	bottomline	= ((windowBounds.bottom - windowBounds.top - kHeaderHeight - 2*kTextMargin -4) / kHexLineHeight) + topline -1;
	lastline	= (GetHandleSize( data ) /16) - (GetHandleSize( data ) %16? 0:1);
	
	// scrollbar values
	SInt32 number = lastline - (bottomline - topline);
	if( number <= 0 ) SetControlValue( scrollbar, 0 );
	SetControlMaximum( scrollbar, (number > 0)? number:0 );
	SetControlViewSize( scrollbar, bottomline - topline );
	
	return noErr;
}

/*** INSERT BYTES ***/
Boolean HexWindow::InsertBytes( void *newData, signed long length, unsigned long offset )
{
	signed long size = (signed long) GetHandleSize( data );
	if( size + length <= 0 ) length = -size;	// don't dispose of resource, just set it to zero length
	
	SInt8 state = HGetState( data );
	HLock( data );
	if( length > 0 )		// writing things
	{
		SetHandleSize( data, size + length );
		if( MemError() ) return false;
		BlockMoveData( *data + offset, *data + offset + length, size - offset );
		BlockMoveData( newData, *data + offset, length );
	}
	else if( length < 0 )	// deleting things
	{
		BlockMoveData( *data + offset, *data + offset + length, size - offset );
		SetHandleSize( data, size + length );
		if( MemError() ) return false;
	}
	HSetState( data, state );
	return true;
}