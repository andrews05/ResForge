#import <Foundation/Foundation.h>

/* Your plug-in's principle class must implement initWithResource: else it won't be loaded by ResKnife (so neh-neh!), all other methods are optional */

@protocol ResKnifePluginProtocol

/*!	@function	initWithResource:
 *	@abstract	Your plug-in is inited with this call. This allows immediate access to the resource you are about to edit, and with this information you can set up different windows, etc.
 */
- (id)initWithResource:(id)newResource;

@end