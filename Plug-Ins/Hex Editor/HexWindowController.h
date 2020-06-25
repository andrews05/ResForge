#import <Cocoa/Cocoa.h>
#import <HexFiend/HexFiend.h>

#import "ResKnifePluginProtocol.h"
#import "ResKnifeResourceProtocol.h"

#define kWindowStepWidthPerChar		28
#define kWindowStepCharsPerStep		1

/*!
@class		HexWindowController
@author		Nicholas Shanks
@pending	Add a category to NSString to convert from hex-formatted strings to NSData objects.
*/

/* Based on HexEdit by Bill Bumgardner, Lane Roath & myself: http://hexedit.sourceforge.net/ */
/* Some ideas, method names, and occasionally code stolen from HexEditor by Raphael Sebbe: http://raphaelsebbe.multimania.com/ */

@class FindSheetController;

@interface HexWindowController : NSWindowController <ResKnifePlugin>
{
	FindSheetController *sheetController;
	NSUndoManager       *undoManager;
}
@property (weak) IBOutlet HFTextView *textView;
@property id <ResKnifeResource> resource;   // The resource we operate on.

// conform to the ResKnifePlugin with the inclusion of these methods
- (instancetype)initWithResource:(id)newResource;

// show find sheet
- (IBAction)showFind:(id)sender;

// save sheet methods
- (IBAction)saveResource:(id)sender;
- (IBAction)revertResource:(id)sender;

@end
