#import <AppKit/AppKit.h>
#import "HexEditorDelegate.h"

#import "ResKnifePluginProtocol.h"
#import "ResKnifeResourceProtocol.h"

@interface HexWindowController : NSWindowController <ResKnifePluginProtocol>
{
	IBOutlet HexEditorDelegate	*hexDelegate;
    IBOutlet NSTextView			*ascii;
    IBOutlet NSTextView			*hex;
    IBOutlet NSTextView			*offset;
    IBOutlet NSTextField		*message;
	
	id		resource;
}

- (void)resourceDidChange:(NSNotification *)notification;
- (void)refreshData:(NSData *)data;

// conform to the ResKnifePluginProtocol with the inclusion of these methods
- (id)initWithResource:(id)newResource;

// accessors
- (id)resource;
- (NSData *)data;

@end
