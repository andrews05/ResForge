#import <Cocoa/Cocoa.h>

#import "ResKnifePluginProtocol.h"
#import "ResKnifeResourceProtocol.h"

@interface TemplateWindowController : NSWindowController <ResKnifePluginProtocol, ResKnifeTemplatePluginProtocol>
{
	IBOutlet NSView	*containerView;
	
	NSMutableArray	*tmpl;
	NSMutableArray	*res;
	id <ResKnifeResourceProtocol>	resource;
}

// normal methods
- (void)readTemplate:(id <ResKnifeResourceProtocol>)tmpl;
- (void)parseData;
- (void)createUI;
- (void)enumerateElements:(NSMutableArray *)elements;
- (void)resourceDataDidChange:(NSNotification *)notification;
- (void)refreshData:(NSData *)data;

// accessors
- (id)resource;
- (NSData *)data;

@end
