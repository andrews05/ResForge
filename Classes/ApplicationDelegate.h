#import <Cocoa/Cocoa.h>

/*!
@header			ApplicationDelegate.h
@abstract		This class is the delegate object for NSApp.
*/

/*!
@class			ApplicationDelegate
@abstract		This class is the delegate object for NSApp.
*/
@class OpenPanelDelegate;

@interface ApplicationDelegate : NSObject <NSApplicationDelegate>
{
/*!	@var icons					A dictionary within which to cache icons. Keys are four-character <tt>NSStrings</tt> representing <tt>ResTypes</tt>. */
	NSMutableDictionary			*_icons;
}
@property IBOutlet OpenPanelDelegate *openPanelDelegate;
@property NSWindowController *prefsController;

/*!
@method			showAbout:
@abstract		Displays the about box located in <b>AboutPanel.nib</b>.
*/
- (IBAction)showAbout:(id)sender;

/*!
@method			visitWebsite:
@abstract		Takes the user to <i>http://web.nickshanks.com/resknife/</i>.
*/
- (IBAction)visitWebsite:(id)sender;

/*!
@method			visitSourceforge:
@abstract		Takes the user to <i>http://resknife.sourceforge.net/</i>.
*/
- (IBAction)visitSourceforge:(id)sender;

/*!
@method			emailDeveloper:
@abstract		Launches email client and inserts <i>resknife@nickshanks.com</i> into To field.
*/
- (IBAction)emailDeveloper:(id)sender;

/*!
@method			showInfo:
@abstract		Displays the Info panel stored in <b>InfoWindow.nib</b>
*/
- (IBAction)showInfo:(id)sender;

/*!
@method			showPasteboard:
@abstract		Displays the pasteboard document, a singleton instance of class <tt>PasteboardDocument</tt>
*/
- (IBAction)showPasteboard:(id)sender;

/*!
@method			showPrefs:
@abstract		Displays the preferences panel stored in <b>PrefsWindow.nib</b>
*/
- (IBAction)showPrefs:(id)sender;

/* accessors */

/*!
@method			openPanelDelegate
@abstract		Accessor method for the <tt>openPanelDelegate</tt> instance variable.
*/
- (OpenPanelDelegate *)openPanelDelegate;

/*!
@@method		iconForResourceType:
@abstract		Returns the icon to be used throughout the UI for any given resource type.
*/
- (NSImage *)iconForResourceType:(OSType)resourceType;

/*!
@@method		_icons
@abstract		Private accessor method for the <tt>_icons</tt> instance variable.
*/
- (NSMutableDictionary *)_icons;

/*!
@method			icons
@abstract		Accessor method for the <tt>_icons</tt> instance variable. Returns an immutable dictionary.
*/
- (NSDictionary *)icons;

@end
