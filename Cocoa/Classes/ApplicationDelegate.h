#import <Cocoa/Cocoa.h>

/*!	@header			ApplicationDelegate.h
 *	@discussion		This class is the delegate object for NSApp.
 */

/*!	@class			ApplicationDelegate
 *	@discussion		This class is the delegate object for NSApp.
 */

@interface ApplicationDelegate : NSObject
{
/*!	@var icons		A dictionary within which to cache icons. Keys are four-character <tt>NSStrings</tt> representing <tt>ResTypes</tt>. */
	NSMutableDictionary *icons;
}

/*! @function		showAbout:
 *	@discussion		Displays the about box located in <b>AboutPanel.nib</b>.
 */
- (IBAction)showAbout:(id)sender;

/*! @function		visitWebsite:
 *	@discussion		Takes the user to <i>http://web.nickshanks.com/resknife/</i>.
 */
- (IBAction)visitWebsite:(id)sender;

/*! @function		visitSourceforge:
 *	@discussion		Takes the user to <i>http://resknife.sourceforge.net/</i>.
 */
- (IBAction)visitSourceforge:(id)sender;

/*! @function		emailDeveloper:
 *	@discussion		Launches email client and inserts <i>resknife@nickshanks.com</i> into To field.
 */
- (IBAction)emailDeveloper:(id)sender;

/*! @function		showInfo:
 *	@discussion		Displays the Info panel stored in <b>InfoWindow.nib</b>
 */
- (IBAction)showInfo:(id)sender;

/*! @function		showPrefs:
 *	@discussion		Displays the preferences panel stored in <b>PrefsWindow.nib</b>
 */
- (IBAction)showPrefs:(id)sender;

/*! @function		initUserDefaults
 *	@discussion		Initalises any unset user preferences to default values as read in from <b>defaults.plist</b>.
 */
- (void)initUserDefaults;

/*! @function		icons
 *	@discussion		Accessor method for the <tt>icons</tt> instance variable.
 */
- (NSDictionary *)icons;

@end
 
@interface NSSavePanel (PackageBrowser)

@end