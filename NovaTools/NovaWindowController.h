#import <Cocoa/Cocoa.h>
#import "Structs.h"
#import "DataSource.h"

#import "ResKnifePluginProtocol.h"
#import "ResKnifeResourceProtocol.h"

@interface NovaWindowController : NSWindowController <ResKnifePluginProtocol>
{
	id <ResKnifeResourceProtocol>	resource;
	NSUndoManager					*undoManager;
	
	DataSource *governmentDataSource;
	DataSource *planetDataSource;
	DataSource *shipDataSource;
}

- (void)setResource:(id <ResKnifeResourceProtocol>)newResource;
- (void)setUndoManager:(NSUndoManager *)newUndoManager;
- (IBAction)toggleResID:(id)sender;

- (void)resourceNameDidChange:(NSNotification *)notification;

@end
