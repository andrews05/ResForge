#import <Cocoa/Cocoa.h>
#import "HexEditorDelegate.h"
#import "HexTextView.h"

#import "ResKnifePluginProtocol.h"
#import "ResKnifeResourceProtocol.h"

#define kWindowStepWidthPerChar		28
#define kWindowStepCharsPerStep		1

@interface HexWindowController : NSWindowController <ResKnifePluginProtocol>
{
	IBOutlet HexEditorDelegate	*hexDelegate;
	IBOutlet NSScrollView		*asciiScroll;
	IBOutlet NSScrollView		*hexScroll;
	IBOutlet NSTextView			*ascii;
	IBOutlet NSTextView			*hex;
	IBOutlet NSTextView			*offset;
	IBOutlet NSTextField		*message;
	IBOutlet NSMenu				*pasteSubmenu;
	
	NSUndoManager					*undoManager;
	id <ResKnifeResourceProtocol>	resource;
	id <ResKnifeResourceProtocol>	backup;
	BOOL							liveEdit;
	int								bytesPerRow;
}

// conform to the ResKnifePluginProtocol with the inclusion of these methods
- (id)initWithResource:(id)newResource;

// show find sheet
- (IBAction)showFind:(id)sender;

// save sheet methods
- (void)saveSheetDidClose:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)saveResource;
- (void)revertResource;

// normal methods
- (void)viewDidScroll:(NSNotification *)notification;
- (void)resourceNameDidChange:(NSNotification *)notification;
- (void)resourceDataDidChange:(NSNotification *)notification;
- (void)resourceWasSaved:(NSNotification *)notification;
- (void)refreshData:(NSData *)data;

// accessors
- (id)resource;
- (NSData *)data;
- (int)bytesPerRow;

@end
