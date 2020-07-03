#import <Cocoa/Cocoa.h>

@class ResourceDocument;

@interface CreateResourceSheetController : NSWindowController
{
	IBOutlet NSButton		*cancelButton;
	IBOutlet NSButton		*createButton;
	IBOutlet NSTextField	*nameView;
	IBOutlet NSTextField	*resIDView;
	IBOutlet NSTextField	*typeView;
	
	ResourceDocument		*document;
}

- (void)showCreateResourceSheet:(ResourceDocument *)sheetDoc withType:(NSString *)type andID:(NSNumber *)resID;

@end
