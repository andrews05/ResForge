/* =============================================================================
	PROJECT:	ResKnife
	FILE:		NuTemplateWindowController.h
	
	PURPOSE:	This is the main class of our template editor. Every
				resource editor's main class implements the
				ResKnifePluginProtocol. Every editor should implement
				initWithResource:. Only implement initWithResources: if you feel
				like writing a template editor.
				
				Note that your plugin is responsible for committing suicide
				after its window has been closed. If you subclass it from
				NSWindowController, the controller will take care of that
				for you, according to a guy named Doug.
	
	AUTHORS:	M. Uli Kusterer, witness(at)zathras.de, (c) 2003.
	
	REVISIONS:
		2003-07-31  UK  Created.
   ========================================================================== */

/* -----------------------------------------------------------------------------
	Headers:
   -------------------------------------------------------------------------- */

#import <Cocoa/Cocoa.h>
#import "ResKnifePluginProtocol.h"
#import "ResKnifeResourceProtocol.h"


/* -----------------------------------------------------------------------------
	Interface:
   -------------------------------------------------------------------------- */

@interface NuTemplateWindowController : NSWindowController <ResKnifeTemplatePluginProtocol>
{
	IBOutlet NSOutlineView*			displayList;		// template display (debug only).
	IBOutlet NSOutlineView*			dataList;			// Data display.

	NSMutableArray*					templateStructure;	// Pre-parsed form of our template.
	NSMutableArray*					resourceStructure;	// Parsed form of our resource.
	id <ResKnifeResourceProtocol>	resource;			// The resource we operate on.
	NSMenuItem*						createFieldItem;	// "Create Resource" menu item we usurp to create list items.
}

-(void)	readTemplate: (id <ResKnifeResourceProtocol>)tmplRes;
-(void)	reloadResData;
-(void)	resourceDataDidChange: (NSNotification*)notification;
-(void)	writeResData;

-(IBAction)	showCreateResourceSheet: (id)sender;
-(IBAction)	cut: (id)sender;
-(IBAction)	copy: (id)sender;
-(IBAction)	paste: (id)sender;
-(IBAction)	clear: (id)sender;
-(IBAction)	saveDocument: (id)sender;


@end
