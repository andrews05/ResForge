#import <Cocoa/Cocoa.h>

#import "ResKnifePluginProtocol.h"
#import "ResKnifeResourceProtocol.h"

@interface TemplateWindowController : NSWindowController <ResKnifePluginProtocol>
{
	IBOutlet NSMatrix	*fieldsMatrix;
	
	NSMutableArray	*tmpl;
	NSMutableArray	*res;
	id <ResKnifeResourceProtocol>	resource;
}

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
