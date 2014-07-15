#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import "Structs.h"
#import "DataSource.h"

#import "ResKnifePluginProtocol.h"
#import "ResKnifeResourceProtocol.h"

#define localCenter		[NSNotificationCenter defaultCenter]

@interface NovaWindowController : NSWindowController <ResKnifePlugin>
{
	//NSNotificationCenter			*localCenter;
	NSBundle						*plugBundle;
	
	DataSource *descriptionDataSource;
	DataSource *governmentDataSource;
	DataSource *pictureDataSource;
	DataSource *planetDataSource;
	DataSource *shipDataSource;
	DataSource *soundDataSource;
	DataSource *spinDataSource;
}
@property (strong) id<ResKnifeResource> resource;
@property (strong) NSUndoManager *undoManager;
@property (strong) DataSource *descriptionDataSource;
@property (strong) DataSource *governmentDataSource;
@property (strong) DataSource *pictureDataSource;
@property (strong) DataSource *planetDataSource;
@property (strong) DataSource *shipDataSource;
@property (strong) DataSource *soundDataSource;
@property (strong) DataSource *spinDataSource;

- (IBAction)toggleResID:(id)sender;

- (void)resourceNameDidChange:(NSNotification *)notification;
- (void)saveSheetDidClose:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
- (void)invalidValuesSheetDidClose:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;

@end

@interface NovaWindowController (AbstractNovaMethods)

- (NSDictionary *)validateValues;
- (void)saveResource;

@end
