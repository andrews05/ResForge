#import <Cocoa/Cocoa.h>

@class ResourceDocument, Resource;

@interface ResourceDataSource : NSObject <NSOutlineViewDataSource>
@property (strong) NSMutableDictionary<NSString*,NSMutableArray<Resource*>*> *resourcesByType;
@property (strong) NSMutableArray<NSString*> *allTypes;
@property (weak) IBOutlet NSOutlineView		*outlineView;
@property (weak) IBOutlet ResourceDocument	*document;

- (NSArray *)resources;

- (void)addResources:(NSArray<Resource*> *)resources;

- (void)addResource:(Resource *)resource;
- (void)removeResource:(Resource *)resource;
- (void)removeResourceFromTypedList:(Resource *)inResource;

- (NSArray *)allResourcesForItems:(NSArray *)items;
- (void)selectResources:(NSArray *)resources;

- (short)uniqueIDForType:(NSString *)type;
- (short)defaultIDForType:(NSString *)type;

- (Resource *)resourceOfType:(NSString *)type andID:(short)resID;
- (Resource *)resourceOfType:(NSString *)type withName:(NSString *)name;
- (NSArray *)allResourcesOfType:(NSString *)type;

@end
