#if !TARGET_API_MAC_OS8
	#include <Carbon/Carbon.h>
#endif

#ifndef _ResKnife_Plug_
	#define _ResKnife_Plug_ 1
	#include "HostCallbacks.h"
#endif

#ifndef _ResKnife_HexEditor_
#define _ResKnife_HexEditor_

// abbreviations
#define null		NULL
#define Use_Nibs	0
#define	Use_GWorlds	1

// Easier constants
#define RGBColour	RGBColor

// Easier API call names
#define GetWindowRefCon( window )						(long)	GetWRefCon( window )
#define SetWindowRefCon( window, refcon )						SetWRefCon( window, refcon )
#define GetWindowTitle( window, string )						GetWTitle( window, string )
#define SetWindowTitle( window, name )							SetWTitle( window, name )
#define InvalidateRect( bounds )								InvalRect( bounds )
#define InvalidateWindowRect( window, bounds )		(OSStatus)	InvalWindowRect( window, bounds )
#define RectToRegion( region, rect )							RectRgn( region, rect )
#define SetPoint( point, x, y )									SetPt( point, x, y )
/* apperance.h */
#define SetThemeTextColour( c, d, cd )				(OSStatus)	SetThemeTextColor( c, d, cd )
#define IsThemeInColour( d, cd )					(Boolean)	IsThemeInColor( d, cd )
#define GetThemeAccentColours( out )				(OSStatus)	GetThemeAccentColors( out )
#define SetThemeTextColourForWindow( w, a, d, cd )	(OSStatus)	SetThemeTextColorForWindow( w, a, d, cd )
#define GetThemeBrushAsColour( b, d, cd, out )		(OSStatus)	GetThemeBrushAsColor( b, d, cd, out )
#define GetThemeTextColour( c, d, cd, out)			(OSStatus)	GetThemeTextColor( c, d, cd, out)
/* some other file */
#define HilightColour( colour )									HiliteColor( colour )
#define GetPortHilightColour( window, colour )					GetPortHiliteColor( window, colour )

/* Global Variables */
struct globals
{
	// application
	Str255		fragName;
	Str255		prefsName;
	
	// system info
	SInt32		systemVersion;
	Boolean		dragAvailable;
	Boolean		translucentDrag;
	Boolean		navAvailable;
	Boolean		useAppearance;
	
	// colours
	RGBColour	white;			// 0xFFFF, 65535
	RGBColour	bgColour;		// 0xEEEE, 61166
	RGBColour	sortColour;		// 0xDDDD, 56797
	RGBColour	bevelColour;	// 0xAAAA, 43690
	RGBColour	textColour;		// 0x7777, 30583
	RGBColour	frameColour;	// 0x5555, 21845
	RGBColour	black;			// 0x0000, 0
};

/* Preferences */
struct prefs
{
	UInt32	version;				// == kHexEditorCurrentVersion, when saved to disk allows older prefs to be read in
	
	// highest and lowest chars displayed
	UInt8	lowChar;
	UInt8	highChar;
	UInt8	GWorldDepth;
};

// MacOS versions
const SInt32 kMacOSSevenPointOne	= 0x00000710;
const SInt32 kMacOSSevenPointFivePointFive	= 0x00000755;
const SInt32 kMacOSEight			= 0x00000800;
const SInt32 kMacOSEightPointFive	= 0x00000850;
const SInt32 kMacOSEightPointSix	= 0x00000860;
const SInt32 kMacOSNine				= 0x00000900;
const SInt32 kMacOSNinePointOne		= 0x00000910;
const SInt32 kMacOSTen				= 0x00001000;

const SInt32 kMacOS71				= kMacOSSevenPointOne;
const SInt32 kMacOS755				= kMacOSSevenPointFivePointFive;
const SInt32 kMacOS8				= kMacOSEight;
const SInt32 kMacOS85				= kMacOSEightPointFive;
const SInt32 kMacOS86				= kMacOSEightPointSix;
const SInt32 kMacOS9				= kMacOSNine;
const SInt32 kMacOS91				= kMacOSNinePointOne;
const SInt32 kMacOSX				= kMacOSTen;

/*** APPLE EVENT SUPPORT ***/
const OSType kResEditorAEType		= FOUR_CHAR_CODE('ResK');
const OSType kResTransferType		= FOUR_CHAR_CODE('rsrc');

enum DragReceiveType	// copy & paste uses these too
{
	kScrapFlavorTypeHex		= FOUR_CHAR_CODE('HEX '),
	kScrapFlavorTypeResource = kResTransferType
};

/*** CONSTANTS ***/
const UInt32 kHexEditorCurrentVersion = 0x00030003;
const UInt16 kHeaderHeight			= 20;
const UInt16 kScrollBarWidth		= 16;
const UInt16 kTextMargin			= 5;		// top & bottom margin for hand-drawn editing areas
const UInt16 kTextFrameBorder		= 9;		// border around controls
const UInt16 kTextInnerBuffer		= 2;		// border within controls
const UInt16 kHexCharWidth			= 7;
const UInt16 kHexLineHeight			= 11;
const UInt16 kDataBlockWidth		= (8*kHexCharWidth);
const UInt16 kOffsetColumnWidth		= (10*kHexCharWidth);		// no need to consider border on leftmost edge of hex field
const UInt16 kMinimumWindowWidth	= kOffsetColumnWidth + (4*kDataBlockWidth) + (3*kHexCharWidth) + kScrollBarWidth;
const UInt16 kDefaultWindowWidth	= kMinimumWindowWidth + (4*kDataBlockWidth);
const UInt16 kMinimumWindowHeight	= kHeaderHeight + (2*kTextMargin) + (10*kHexLineHeight) +4;
const UInt16 kDefaultWindowHeight	= kMinimumWindowHeight + (6*kHexLineHeight);

const UInt32 kHeaderSignature		= FOUR_CHAR_CODE('head');
const UInt32 kLeftTextSignature		= FOUR_CHAR_CODE('left');
const UInt32 kRightTextSignature	= FOUR_CHAR_CODE('rght');
const UInt32 kOffsetTextSignature	= FOUR_CHAR_CODE('offs');
const UInt32 kHexTextSignature		= FOUR_CHAR_CODE('hex ');
const UInt32 kAsciiTextSignature	= FOUR_CHAR_CODE('asci');
const UInt32 kScrollbarSignature	= FOUR_CHAR_CODE('scrl');

/* RESOURCES */

enum	// menus
{
	kEditorMenu		= 128
};

enum	// windows
{
	kFileWindow7	= 128,
	kFileWindow8	= 129
};

enum	// controls
{
	kSystem7ScrollBarControl	= 128,
	kAppearanceScrollBarControl	= 129,
	kNormalHeaderControl		= 130
};

#endif
