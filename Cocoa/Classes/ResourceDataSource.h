#import <Cocoa/Cocoa.h>
#import "Resource.h"

@class CreateResourceSheetController;

@interface ResourceDataSource : NSObject
{
	IBOutlet NSWindow		*window;
	IBOutlet NSOutlineView	*outlineView;
	IBOutlet CreateResourceSheetController	*createResourceSheetController;
	
	NSMutableArray	*resources;
}

- (CreateResourceSheetController *)createResourceSheetController;
- (NSWindow *)window;
- (NSArray *)resources;
- (void)setResources:(NSMutableArray *)newResources;
- (void)addResource:(Resource *)resource;
- (void)generateTestData;

@end
