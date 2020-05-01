/* =============================================================================
	PROJECT:	ResKnife
	FILE:		TemplateWindowController.h
	
	PURPOSE:	This is the main class of our template editor. Every
				resource editor's main class implements the
				ResKnifePlugin. Every editor should implement
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
#import "ElementList.h"

@interface TemplateWindowController : NSWindowController <ResKnifeTemplatePlugin, NSOutlineViewDataSource, NSOutlineViewDelegate>
{
	ElementList *resourceStructure;		// Parsed form of our resource.
	BOOL liveEdit;
}
@property IBOutlet NSOutlineView *dataList; // Data display.
@property id <ResKnifeResource> resource;   // The resource we operate on.
@property id <ResKnifeResource> backup;     // The original resource.


- (void)readTemplate:(id <ResKnifeResource>)tmplRes;
- (void)loadResource;
- (IBAction)dataClicked:(id)sender;
- (IBAction)itemValueUpdated:(id)sender;
- (IBAction)saveResource:(id)sender;
- (IBAction)revertResource:(id)sender;
- (IBAction)createListEntry:(id)sender;
- (IBAction)cut:(id)sender;
- (IBAction)copy:(id)sender;
- (IBAction)paste:(id)sender;
- (IBAction)delete:(id)sender;

@end
