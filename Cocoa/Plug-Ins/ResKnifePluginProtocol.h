#import <Foundation/Foundation.h>
#import "ResKnifeResourceProtocol.h"

/* Your plug-in's principal class must implement initWithResource: else it
won't be loaded by ResKnife (so neh-neh!), all other methods are optional,
and thus declared in ResKnifeInformalPluginProtocol. */
@protocol ResKnifePluginProtocol

/*!	@method		initWithResource:
 *	@abstract	Your plug-in is inited with this call. This allows immediate
				access to the resource you are about to edit, and with this
				information you can set up different windows, etc.
 */
- (id)initWithResource:(id <ResKnifeResourceProtocol>)newResource;

@end


/* Optional methods your plugin may implement to provide additional
functionality: */

@interface ResKnifeInformalPluginProtocol

/*! @method		dataForFileExport:
	@abstract   Return the data to be saved to disk when your resource is
				exported to a file. By default the host application substitutes
				the raw resource data if you don't implement this. The idea is
				that this export function is non-lossy, i.e. only override this
				if there is a format that is a 100% equivalent to your data. */
+(NSData*)		dataForFileExport: (id <ResKnifeResourceProtocol>)theRes;
/*! @method		extensionForFileExport:
	@abstract   If you implement dataForFileExport, return a string here that
				provides the proper file extension for your file. By default the
				host application substitutes the resource type here. */
+(NSString*)	extensionForFileExport: (id <ResKnifeResourceProtocol>)theRes;

/*! @method		imageForImageFileExport:
	@abstract   Return the image to be saved to disk when your resource is
				exported to an image file. If your resource contains image
				data, this is your opportunity to export it to a well-known
				image format. This will be a lossy conversion to a TIFF
				file. */
+(NSImage*)		imageForImageFileExport: (id <ResKnifeResourceProtocol>)theRes;
/*! @method		extensionForImageFileExport:
	@abstract   If you implement imageForImageFileExport, return a string here that
				provides the proper file extension for your file. By default the
				host application substitutes "tiff" here. */
+(NSString*)	extensionForImageFileExport: (id <ResKnifeResourceProtocol>)theRes;

@end


/* If you're implementing a template editor, you should implement this
	extended protocol instead of the regular plugin protocol: */

@protocol ResKnifeTemplatePluginProtocol <ResKnifePluginProtocol>

- (id)initWithResources:(id <ResKnifeResourceProtocol>)newResource, ...;

@end