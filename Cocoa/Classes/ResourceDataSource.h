#import <Cocoa/Cocoa.h>

@class ResourceDocument, Resource;

@interface ResourceDataSource : NSObject
{
	IBOutlet NSOutlineView		*outlineView;
	IBOutlet NSWindow			*window;
	IBOutlet ResourceDocument	*document;
	
	NSMutableArray	*resources;
}

- (NSWindow *)window;
- (NSArray *)resources;
- (void)setResources:(NSMutableArray *)newResources;
- (void)addResource:(Resource *)resource;
- (void)removeResource:(Resource *)resource;

// accessors
- (Resource *)resourceOfType:(NSString *)type andID:(NSNumber *)resID;
- (Resource *)resourceOfType:(NSString *)type withName:(NSString *)name;
- (NSArray *)allResourcesOfType:(NSString *)type;

@end
