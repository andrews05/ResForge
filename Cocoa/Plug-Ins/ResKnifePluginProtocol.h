#import <Foundation/Foundation.h>

/* Your plug-in's principle class must implement the following methods else it won't be loaded by ResKnife (so neh-neh!) */

@protocol ResKnifePluginProtocol

/*!	@function	initWithResource:newResource
 *	@abstract	Your plug-in is inited with this call. This allows immediate access to the resource you are about to edit, and with this information you can set up different windows, etc.
 */
- (id)initWithResource:(id)newResource;

/*!	@function	refreshData:data
 *	@abstract	When your data set is changed via some means other than yourslf, you receive this.
 */
- (void)refreshData:(NSData *)data;

@end
