/*

With thanks to:							  For:
  Jim Luther								MoreFiles
  Bryan K. Ressler & Bradley D. Mohr		Asynchronous SoundHelper
  John Montbriand & Pete Gontier			FinderDragPro

*/

// interesting function I found: CFBundleOpenBundleResourceMap()

#if defined(__MWERKS__)		// compiling with CodeWarrior
	#if __profile__
		#include <Profiler.h>
	#endif
#else						// compiling with ProjectBuilder, use frameworks
	#define NO_DATA_BROWSER_TWEAKS 0
	#define USE_OLD_DATA_BROWSER_STRUCTS 0
	#include <Carbon/Carbon.h>
#endif

#ifndef _ResKnife_
#define _ResKnife_

/*!
 *	@header ResKnife Global Header
 *	Imported by all ResKnife's C++ source files, this defines various structures and constants which have an application-wide domain.
 */

// compile options
#if TARGET_API_MAC_CARBON
	#define USE_NIBS 0		// toggle this
#else
	#define USE_NIBS 0		// leave this set to zero
#endif

// include my generic API abbreviations
#include "Generic.h"

/*** STRUCTURES ***/

// type definitions
typedef class ResourceObject	ResourceObject,			*ResourceObjectPtr;
typedef class PlugObject		PlugObject,				*PlugObjectPtr;
typedef class WindowObject		WindowObject,			*WindowObjectPtr;
typedef class FileWindow			FileWindow,			*FileWindowPtr;
typedef class PlugWindow			PlugWindow,			*PlugWindowPtr;
typedef class PickerWindow				PickerWindow,	*PickerWindowPtr;
typedef class EditorWindow				EditorWindow,	*EditorWindowPtr;
typedef class InspectorWindow		InspectorWindow,	*InspectorWindowPtr;

/* Global Variables */
struct globals
{
	// application
	Str255	appName;
	Str255	prefsName;
	Boolean	quitting;
	Boolean cancelQuit;
	Boolean	frontApp;
	Boolean	asyncSound;		// async sound initalised
	Boolean	callSH;			// call sound idle
	short	appResFile;
	Handle	emergencyMemory;
	EventLoopTimerRef idleTimer;	// for SHIdle()
	
	// system info
	SInt32	systemVersion;
	SInt32	carbonVersion;
	Boolean	dragAvailable;
	Boolean	translucentDrag;
	Boolean	navAvailable;
	Boolean	appearanceAvailable;
	Boolean windowMgrAvailable;
	Boolean extendedWindowAttr;
	
	// files
	UInt16		tempCount;	// number of temporary files opened, so names don't clash
	
	// dialogs
	DialogPtr	prefsDialog;
	Boolean		protectPrefs;	// if newer version of prefs file exists, will not overwrite
	InspectorWindowPtr inspector;
	
	// colours
	RGBColor	white;			// 0xFFFF, 65535
	RGBColor	bgColour;		// 0xEEEE, 61166
	RGBColor	sortColour;		// 0xDDDD, 56797
	RGBColor	bevelColour;	// 0xAAAA, 43690
	RGBColor	textColour;		// 0x7777, 30583
	RGBColor	frameColour;	// 0x5555, 21845
	RGBColor	black;			// 0x0000, 0
	
	// debugging
	Boolean		debug;
	Boolean		surpressErrors;
	Boolean		useAppleEvents;
	Boolean		useAppearance;
	Boolean		useNavServices;
	Boolean		useSheets;		// OS X only
};

/*!
 *	@struct			prefs
 *	@abstract		Appplication-wide user preferences
 *	@discussion		Stores all user preferences in memory to avoid needless disk access. This structure is simply written straight to disk when the preferences are saved.
 *	@field version	Identifies which version of ResKnife saved the prefs file (allowing future versions to parse the data contained).
 */
struct prefs
{
	UInt32	version;				// == kResKnifeCurrentVersion, when saved to disk allows older prefs to be read in
	Boolean	quitIfNoWindowsAreOpen; // silly name! - perhaps grandmaMode ?
	Boolean	autoSave;
	UInt32	autoSaveInterval;		// should be in units of time
	Boolean	warnOnDelete;			// "Are you sure?" dialog, © Microsoft 1986-2003
};

/*** CONSTANTS ***/

// Mac OS versions
const SInt32 kMacOS607				= 0x00000607;
const SInt32 kMacOS7				= 0x00000710;
const SInt32 kMacOS71				= 0x00000710;
const SInt32 kMacOS755				= 0x00000755;
const SInt32 kMacOS8				= 0x00000800;
const SInt32 kMacOS85				= 0x00000850;
const SInt32 kMacOS86				= 0x00000860;
const SInt32 kMacOS9				= 0x00000900;
const SInt32 kMacOS904				= 0x00000904;
const SInt32 kMacOS91				= 0x00000910;
const SInt32 kMacOS921				= 0x00000921;
const SInt32 kMacOS10				= 0x00001000;
const SInt32 kMacOS101				= 0x00001010;
const SInt32 kMacOS102				= 0x00001020;
const SInt32 kMacOSX				= kMacOS10;

// CarbonLib versions
const SInt32 kCarbonLib104			= 0x00000104;
const SInt32 kCarbonLib11			= 0x00000110;
const SInt32 kCarbonLib12			= 0x00000120;
const SInt32 kCarbonLib125			= 0x00000125;
const SInt32 kCarbonLib131			= 0x00000131;
const SInt32 kCarbonLib14			= 0x00000140;
const SInt32 kCarbonLib145			= 0x00000145;
const SInt32 kCarbonLib15			= 0x00000150;
const SInt32 kCarbonLib16			= 0x00000160;

// ResKnife version & file types
const UInt32 kCurrentVersion	= 0x00040001;
const UInt32 kResKnifeCreator	= FOUR_CHAR_CODE('ResK');
const UInt32 kResourceFileType	= FOUR_CHAR_CODE('rsrc');
const UInt32 kResourceTransferType = FOUR_CHAR_CODE('rsrc');	// for copy/paste and drags

// memory
const UInt16 kMinimumFreeMemory		= 20 * 1024;	// if we have over 20 KB we're alright
const UInt16 kEmergencyMemory		= 40 * 1024;	// 40 KB are put aside for emergencies

// window kinds
enum WindowKind
{
	kFileWindowKind = 1,
	kPickerWindowKind,
	kEditorWindowKind,
	kInspectorWindowKind
};

// control sizes
const UInt16 kScrollBarWidth		= 16;

/* RESOURCES */

/*!
 *	@enum Menu Resources
 *	@discussion Contains all resource IDs for menu items and all ascociated item numbers.
 */
enum	// menus
{
	kClassicMenuBar				= 128,
	
	kAppleMenu					= 128,
	kAppleMenuAboutItem			= 1,
	
	kFileMenu					= 129,
	kFileMenuNewFileItem		= 1,
	kFileMenuOpenFileItem,
	kFileMenuCloseWindowItem,
	kFileMenuQuitItem			= 12,
	
	kEditMenu					= 130,
	kEditMenuClearItem			= 7,
	kEditMenuPreferencesItem	= 13,
	
	kResourceMenu				= 131,
	kResourceMenuNewResource	= 1,
	
	kWindowMenu					= 132,
	
	kDebugMenu					= 200,
	kDebugMenuDebugItem			= 1,
	kDebugMenuSurpressErrorsItem = 3,
	kDebugMenuAppleEventsItem,
	kDebugMenuAppearanceItem,
	kDebugMenuNavServicesItem,
	kDebugMenuSheetsItem
};

enum	// application menu
{
	kMenuCommandAbout		= FOUR_CHAR_CODE('abou')
};

enum	// file menu
{
	kMenuCommandNewFile		= FOUR_CHAR_CODE('new '),
	kMenuCommandOpenFile	= FOUR_CHAR_CODE('open'),
	kMenuCommandCloseWindow	= FOUR_CHAR_CODE('clos'),
	kMenuCommandCloseFile	= FOUR_CHAR_CODE('clsf'),
	kMenuCommandSaveFile	= FOUR_CHAR_CODE('save'),
	kMenuCommandSaveFileAs	= FOUR_CHAR_CODE('svas'),
	kMenuCommandRevertFile	= FOUR_CHAR_CODE('rvtf'),
	kMenuCommandPageSetup	= FOUR_CHAR_CODE('setu'),
	kMenuCommandPrint		= FOUR_CHAR_CODE('prin')
};

enum	// edit menu
{
	kMenuCommandFind		= FOUR_CHAR_CODE('find'),
	kMenuCommandFindAgain	= FOUR_CHAR_CODE('agin')
};

enum	// resource menu
{
	kMenuCommandNewResource		= FOUR_CHAR_CODE('newr'),
	kMenuCommandOpenHex			= FOUR_CHAR_CODE('hex '),
	kMenuCommandOpenDefault		= FOUR_CHAR_CODE('edit'),
	kMenuCommandOpenTemplate	= FOUR_CHAR_CODE('tmpl'),
	kMenuCommandOpenSpecific	= FOUR_CHAR_CODE('tmp '),
	kMenuCommandRevertResource	= FOUR_CHAR_CODE('rvtr'),
	kMenuCommandPlaySound		= FOUR_CHAR_CODE('play')
};

enum	// debug menu
{
	kMenuCommandDebug			= FOUR_CHAR_CODE('dbug'),
	kMenuCommandSurpressErrors	= FOUR_CHAR_CODE('surp'),
	kMenuCommandAppleEvents		= FOUR_CHAR_CODE('appl'),
	kMenuCommandAppearance		= FOUR_CHAR_CODE('appr'),
	kMenuCommandNavServices		= FOUR_CHAR_CODE('nav '),
	kMenuCommandSheets			= FOUR_CHAR_CODE('shet')
};

enum	// windows
{
	kFileWindow7				= 128,
	kFileWindow8				= 129
};

enum	// dialogs
{
	kErrorDialog				= 128,
	kNewResourceDialog			= 129
};

enum	// controls
{
	kSystem7ScrollBarControl	= 128,
	kAppearanceScrollBarControl	= 129,
	kNormalHeaderControl		= 130,
	kFileHeaderControl			= 131,
	kEditTextControl			= 132
};

enum	// icons
{
	kSortUpIcon					= 921,
	kSortDownIcon				= 922,
	kDefaultResourceIcon		= 1000
};

enum	// strings
{
	kErrorStrings				= 128,
	kStringUnknownError			= 1,
	kExplanationUnknownError,
	kStringOSNotGoodEnough,
	kExplanationOSNotGoodEnough,
	kStringMinimumCarbonLib,
	kExplanationMinimumCarbonLib,
	kStringRecommendedCarbonLib,
	kExplanationRecommendedCarbonLib,
	
	kDebugStrings				= 129,
	kStringRFNotFound			= 1,
	kExplanationRFNotFound,
	kStringDFNotFound,
	kExplanationDFNotFound,
	
	kFileNameStrings			= 130,
	kStringResKnifeName			= 1,
	kStringPrefsFileName,
	kStringNewDragFileName,
	
	kWindowNameStrings			= 131,
	kStringNewFile				= 1,
	kStringPrefsWindowName,
	kStringInspectorWindowName,
	kStringNewResourceDialogName,
	
	kResourceNameStrings		= 132,
	kStringDataFork				= 1,
	kStringUntitledResource,
	kStringCustomIcon
};

#endif
