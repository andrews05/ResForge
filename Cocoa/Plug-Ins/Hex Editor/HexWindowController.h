#import <Cocoa/Cocoa.h>
#import "HexEditorDelegate.h"
#import "HexTextView.h"

#import "ResKnifePluginProtocol.h"
#import "ResKnifeResourceProtocol.h"

@interface HexWindowController : NSWindowController <ResKnifePluginProtocol>
{
	IBOutlet HexEditorDelegate	*hexDelegate;
    IBOutlet NSTextView			*ascii;
    IBOutlet NSTextView			*hex;
    IBOutlet NSTextView			*offset;
    IBOutlet NSTextField		*message;
    IBOutlet NSMenu				*pasteSubmenu;
	
	NSUndoManager					*undoManager;
	id <ResKnifeResourceProtocol>	resource;
	int								bytesPerRow;
}

// conform to the ResKnifePluginProtocol with the inclusion of these methods
- (id)initWithResource:(id)newResource;

// show find sheet
- (IBAction)showFind:(id)sender;

// normal methods
- (void)viewDidScroll:(NSNotification *)notification;
- (void)resourceNameDidChange:(NSNotification *)notification;
- (void)resourceDataDidChange:(NSNotification *)notification;
- (void)refreshData:(NSData *)data;

// accessors
- (id)resource;
- (NSData *)data;
- (int)bytesPerRow;

@end
