#import "PasteboardWindowController.h"

@implementation PasteboardWindowController

- (instancetype)init
{
	self = [self initWithWindowNibName:@"ResourceDocument"];
	if( self ) [self setWindowFrameAutosaveName:@"PasteboardWindow"];
	return self;
}

+ (id)sharedPasteboardWindowController
{
	static PasteboardWindowController *sharedPasteboardWindowController;
	if( !sharedPasteboardWindowController )
	{
		sharedPasteboardWindowController = [[PasteboardWindowController allocWithZone:nil] init];
	}
	return sharedPasteboardWindowController;
}

@end
