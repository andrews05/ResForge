#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>

@class ResourceDocument;

@interface CreateResourceSheetController : NSWindowController
{
	IBOutlet NSMatrix 		*attributesMatrix;
	IBOutlet NSButton		*cancelButton;
	IBOutlet NSButton		*createButton;
	IBOutlet NSTextField	*nameView;
	IBOutlet NSTextField	*resIDView;
	IBOutlet NSTextField	*typeView;
	IBOutlet NSPopUpButton	*typePopup;
	
	ResourceDocument		*document;
}

- (void)controlTextDidChange:(NSNotification *)notification;

- (void)showCreateResourceSheet:(ResourceDocument *)sheetDoc;
- (IBAction)hideCreateResourceSheet:(id)sender;
- (IBAction)typePopupSelection:(id)sender;

@end