#import "RKDocumentController.h"
#import "ApplicationDelegate.h"
#import "OpenFileDataSource.h"

@implementation RKDocumentController

// because I swap the isa pointer I can't add instance variables, so use statics instead (there will only ever be one RKDocumentController)
static id oldDelegate = nil;

- (id)init
{
	self = [super init];
	if( self )
	{
		// for some reason calling -[super init] causes a new instance of self to be returned (which is not of my subclass) so to get my overridden methods called again, I have to do this...
		isa = [RKDocumentController class];
		oldDelegate = [[NSOpenPanel openPanel] delegate];
		[[NSOpenPanel openPanel] setDelegate:[[[OpenPanelDelegate alloc] init] autorelease]];
	}
	return self;
}

- (int)runModalOpenPanel:(NSOpenPanel *)openPanel forTypes:(NSArray *)extensions
{
	[openPanel setAccessoryView:[(ApplicationDelegate *)[NSApp delegate] openAuxView]];
	return [super runModalOpenPanel:openPanel forTypes:extensions];
}

@end
