#import <Cocoa/Cocoa.h>

@class ResourceDocument, Resource;

/*!
@class			ResourceDataSource
@pending		This class needs to be made KVC compliant.
*/

@interface ResourceDataSource : NSObject <NSOutlineViewDataSource>
@property (strong) NSMutableDictionary<NSNumber*,NSMutableArray<Resource*>*> *resourcesByType;
@property (strong) NSMutableArray<NSString*> *allTypes;
@property (weak) IBOutlet NSOutlineView		*outlineView;
@property (weak) IBOutlet NSWindow			*window;
@property (weak) IBOutlet ResourceDocument	*document;
/*!
@method		window
*/
- (NSWindow *)window;

/*!
 @method    resources:
 */
- (NSArray *)resources;

/*!
@method		addResources:
*/
- (void)addResources:(NSArray<Resource*> *)resources;

/*!
@method		addResource:
*/
- (void)addResource:(Resource *)resource;

/*!
@method		removeResource:
*/
- (void)removeResource:(Resource *)resource;

/*!
 @method    allResourcesForItems:
 */
- (NSArray *)allResourcesForItems:(NSArray *)items;

/*!
 @method    selectResources:
 */
- (void)selectResources:(NSArray *)resources;

/*!
@method		uniqueIDForType:
*/
- (short)uniqueIDForType:(OSType)type;

/*!
@method		defaultIDForType:
*/
- (short)defaultIDForType:(OSType)type;

/*!
@method		resourceOfType:andID:
*/
- (Resource *)resourceOfType:(OSType)type andID:(short)resID;

/*!
@method		resourceOfType:withName:
*/
- (Resource *)resourceOfType:(OSType)type withName:(NSString *)name;

/*!
@method		allResourcesOfType:
*/
- (NSArray *)allResourcesOfType:(OSType)type;

/*!
@method		allResourceIDsOfType:
*/
- (NSArray *)allResourceIDsOfType:(OSType)type;

@end
