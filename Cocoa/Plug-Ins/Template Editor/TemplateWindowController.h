#import <Cocoa/Cocoa.h>

#import "ResKnifePluginProtocol.h"
#import "ResKnifeResourceProtocol.h"

@interface TemplateWindowController : NSWindowController <ResKnifePluginProtocol>
{
	id <ResKnifeResourceProtocol>	resource;
	NSMutableArray *tmpl;
}

// conform to the ResKnifePluginProtocol with the inclusion of these methods
- (id)initWithResource:(id)newResource;
- (id)initWithResources:(id)newResource, ...;

// normal methods
- (void)readTemplate:(id <ResKnifeResourceProtocol>)tmpl;
- (void)parseData;
- (void)createUI;
- (void)resourceDataDidChange:(NSNotification *)notification;
- (void)refreshData:(NSData *)data;

// accessors
- (id)resource;
- (NSData *)data;

@end
