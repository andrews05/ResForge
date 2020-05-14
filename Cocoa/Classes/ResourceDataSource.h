#import <Cocoa/Cocoa.h>

@class ResourceDocument, Resource;

@interface ResourceDataSource : NSObject <NSOutlineViewDataSource>
@property (strong) NSMutableDictionary<NSNumber*,NSMutableArray<Resource*>*> *resourcesByType;
@property (strong) NSMutableArray<NSString*> *allTypes;
@property (weak) IBOutlet NSOutlineView		*outlineView;
@property (weak) IBOutlet NSWindow          *window;
@property (weak) IBOutlet ResourceDocument	*document;

- (NSArray *)resources;

- (void)addResources:(NSArray<Resource*> *)resources;

- (void)addResource:(Resource *)resource;
- (void)removeResource:(Resource *)resource;
- (void)removeResourceFromTypedList:(Resource *)inResource;

- (NSArray *)allResourcesForItems:(NSArray *)items;
- (void)selectResources:(NSArray *)resources;

- (short)uniqueIDForType:(OSType)type;
- (short)defaultIDForType:(OSType)type;

- (Resource *)resourceOfType:(OSType)type andID:(short)resID;
- (Resource *)resourceOfType:(OSType)type withName:(NSString *)name;
- (NSArray *)allResourcesOfType:(OSType)type;
- (NSArray *)allResourceIDsOfType:(OSType)type;

@end
