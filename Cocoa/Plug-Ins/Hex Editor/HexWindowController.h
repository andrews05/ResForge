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
	
	id		resource;
}

// conform to the ResKnifePluginProtocol with the inclusion of these methods
- (id)initWithResource:(id)newResource;
- (void)refreshData:(NSData *)data;

@end
