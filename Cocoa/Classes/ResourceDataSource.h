#import <Cocoa/Cocoa.h>

@class CreateResourceSheetController, ResourceDocument, Resource;

@interface ResourceDataSource : NSObject
{
	IBOutlet CreateResourceSheetController	*createResourceSheetController;
	IBOutlet ResourceDocument				*document;
	IBOutlet NSOutlineView					*outlineView;
	IBOutlet NSWindow						*window;
	
	NSMutableArray	*resources;
}

- (CreateResourceSheetController *)createResourceSheetController;
- (NSWindow *)window;
- (NSArray *)resources;
- (void)setResources:(NSMutableArray *)newResources;
- (void)addResource:(Resource *)resource;
- (void)removeResource:(Resource *)resource;

@end
