#import <Cocoa/Cocoa.h>
#import "HexEditorDelegate.h"
#import "HexTextView.h"

#import "ResKnifePluginProtocol.h"
#import "ResKnifeResourceProtocol.h"

#define kWindowStepWidthPerChar		28
#define kWindowStepCharsPerStep		1

/*!
@class		HexWindowController
@author		Nicholas Shanks
@pending	Add a category to NSString to convert from hex-formatted strings to NSData objects.
*/

/* Based on HexEdit by Bill Bumgardner, Lane Roath & myself: http://hexedit.sourceforge.net/ */
/* Some ideas, method names, and occasionally code stolen from HexEditor by Raphael Sebbe: http://raphaelsebbe.multimania.com/ */

@interface HexWindowController : NSWindowController <ResKnifePluginProtocol>
{
	IBOutlet HexEditorDelegate	*hexDelegate;
	IBOutlet NSTextView			*offset;		// these four should be phased out whenever possible
	IBOutlet HexTextView		*hex;			// these four should be phased out whenever possible
	IBOutlet AsciiTextView		*ascii;			// these four should be phased out whenever possible
	IBOutlet NSTextField		*message;		// these four should be phased out whenever possible
	IBOutlet NSMenu				*copySubmenu;
	IBOutlet NSMenu				*pasteSubmenu;
	
	id <ResKnifeResourceProtocol>	resource;
	id <ResKnifeResourceProtocol>	backup;
	
	BOOL			liveEdit;
	int				bytesPerRow;
	NSUndoManager   *undoManager;
}

// conform to the ResKnifePluginProtocol with the inclusion of these methods
- (id)initWithResource:(id)newResource;

// show find sheet
- (IBAction)showFind:(id)sender;

// save sheet methods
- (void)saveSheetDidClose:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (IBAction)saveResource:(id)sender;
- (IBAction)revertResource:(id)sender;

// normal methods
- (void)resourceNameDidChange:(NSNotification *)notification;
- (void)resourceDataDidChange:(NSNotification *)notification;
- (void)resourceWasSaved:(NSNotification *)notification;
- (void)refreshData:(NSData *)data;

// accessors
- (id)resource;
- (NSData *)data;
- (int)bytesPerRow;
- (NSMenu *)copySubmenu;
- (NSMenu *)pasteSubmenu;

// bug: these should be functions not class member methods
+ (NSRange)byteRangeFromHexRange:(NSRange)hexRange;
+ (NSRange)hexRangeFromByteRange:(NSRange)byteRange;
+ (NSRange)byteRangeFromAsciiRange:(NSRange)asciiRange;
+ (NSRange)asciiRangeFromByteRange:(NSRange)byteRange;

@end
