#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>

@class ResourceDocument, ResourceDataSource;

@interface CreateResourceSheetController : NSWindowController
{
	IBOutlet ResourceDataSource	*dataSource;
	IBOutlet NSMatrix 		*attributesMatrix;
	IBOutlet NSButton		*cancelButton;
	IBOutlet NSButton		*createButton;
	IBOutlet NSTextField	*nameView;
	IBOutlet NSTextField	*resIDView;
	IBOutlet NSTextField	*typeView;
	IBOutlet NSPopUpButton	*typePopup;
	IBOutlet ResourceDocument *document;
	IBOutlet NSWindow		*parent;
}

- (void)controlTextDidChange:(NSNotification *)notification;

- (IBAction)showCreateResourceSheet:(id)sender;
- (IBAction)hideCreateResourceSheet:(id)sender;
- (IBAction)typePopupSelection:(id)sender;

@end