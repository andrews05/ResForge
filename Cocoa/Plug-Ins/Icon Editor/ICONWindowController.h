/* =============================================================================
	PROJECT:	ResKnife
	FILE:		ICONWindowController.h
	
	PURPOSE:	This is the main class of our bitmap resource editor. Every
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

@interface ICONWindowController : NSWindowController <ResKnifePluginProtocol>
{
	IBOutlet NSImageView			*imageView;
	NSData							*resData;
	NSImage							*resImage;
	id <ResKnifeResourceProtocol>	resource;
}

-(IBAction)		imageViewChanged: (id)sender;

@end
