/* =============================================================================
	PROJECT:	ResKnife
	FILE:		RKEditorRegistry.h
	
	PURPOSE:
		This is a registry where all our resource-editor plugins are looked
		up and entered in a list, so you can ask for the editor for a specific
		resource type and it is returned immediately. This registry reads the
		types a plugin handles from their info.plist. This is better than
		encoding the type in the plugin file name, as file names are not
		guaranteed to be on a case-sensitive file system on Mac, and this also
		allows an editor to register for several resource types.
	
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
	Class interface:
   -------------------------------------------------------------------------- */

@interface RKEditorRegistry : NSObject
{
	NSMutableDictionary*		typeRegistry;   // Private. Use editorForType: to access this.
}

+(RKEditorRegistry*)	mainRegistry;   // There's usually only one object, and this returns or creates it.

-(IBAction)				scanForPlugins: (id)sender;			// Called automatically by mainRegistry.
-(Class)				editorForType: (NSString*)typeStr;  // You probably want to call this.


@end
