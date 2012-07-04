/* =============================================================================
	PROJECT:	ResKnife
	FILE:		TemplateWindowController.h
	
	PURPOSE:	This is the main class of our template editor. Every
				resource editor's main class implements the
				ResKnifePluginProtocol. Every editor should implement
				initWithResource:. Only implement initWithResources:if you feel
				like writing a template editor.
				
				Note that your plugin is responsible for committing suicide
				after its window has been closed. If you subclass it from
				NSWindowController, the controller will take care of that
				for you, according to a guy named Doug.
	
	AUTHORS:	M. Uli Kusterer, witness(at)zathras.de, (c) 2003.
	
	REVISIONS:
		2003-07-31  UK  Created.
   ========================================================================== */

#import <Cocoa/Cocoa.h>
#import "ResKnifePluginProtocol.h"
#import "ResKnifeResourceProtocol.h"

@interface TemplateWindowController : NSWindowController <ResKnifeTemplatePluginProtocol, NSToolbarDelegate>
{
	IBOutlet NSOutlineView *displayList;	// template display (debug only).
	IBOutlet NSOutlineView *dataList;		// Data display.
	IBOutlet NSDrawer *tmplDrawer;
	NSMutableDictionary	*toolbarItems;
	NSMutableArray *templateStructure;		// Pre-parsed form of our template.
	NSMutableArray *resourceStructure;		// Parsed form of our resource.
	id <ResKnifeResourceProtocol> resource;	// The resource we operate on.
	id <ResKnifeResourceProtocol> backup;	// The original resource.
	BOOL liveEdit;
}

- (void)setupToolbar;
- (void)readTemplate:(id <ResKnifeResourceProtocol>)tmplRes;
- (void)loadResource;
- (IBAction)saveResource:(id)sender;
- (IBAction)revertResource:(id)sender;
- (IBAction)createListEntry:(id)sender;
- (IBAction)cut:(id)sender;
- (IBAction)copy:(id)sender;
- (IBAction)paste:(id)sender;
- (IBAction)clear:(id)sender;

@end

@interface NTOutlineView : NSOutlineView
@end