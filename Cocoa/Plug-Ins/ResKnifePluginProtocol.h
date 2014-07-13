#import <Foundation/Foundation.h>
#import "ResKnifeResourceProtocol.h"

/*!
@protocol	ResKnifePlugin
@abstract	Your plug-in's principal class must implement initWithResource: or initWithResources:, all other methods are optional.
@updated	2005-10-03 NGS: Added UTI, MIME Type and OSType methods, renamed extensionForFileExport: to filenameExtensionForFileExport:
@updated	2014-2-23 MTS: Made it part of the ResKnifePlugin as optional methods, as allowed in the Objective C 2.0 runtime.
*/
@protocol ResKnifePlugin <NSObject>

/*!
@method		initWithResource:
@abstract	Your plug-in is inited with this call. This allows immediate access to the resource you are about to edit, and with this information you can set up different windows, etc.
*/
- (id)initWithResource:(id <ResKnifeResource>)inResource;

@end


/*!
@protocol	ResKnifeTemplatePluginProtocol
@abstract	If you're implementing a template editor, you should implement this extended protocol instead of the regular plugin protocol.
*/
@protocol ResKnifeTemplatePluginProtocol <ResKnifePlugin>

/*!
@method		initWithResource:
@abstract	Your template editor is inited with this call. The first argument is the resource to edit, the second is the TMPL resource that defines the data structure.
*/
- (id)initWithResources:(id <ResKnifeResource>)inResource, ...;

@optional

/*!
@method		dataForFileExport:
@abstract   Return the data to be saved to disk when your resource is exported to a flat file. By default the host application uses the raw resource data if you don't implement this. The idea is that this export function is non-lossy, i.e. only override this if there is a format that is a 100% equivalent to your data.
*/
+ (NSData *)dataForFileExport:(id <ResKnifeResource>)resource;

/*	Your plug should implement one of the following four methods.
 *	They are looked for in the order shown below. Only implement one.
 */

/*!
@method		UTIForFileExport:
@abstract   Regardless of whether you implement dataForFileExport, you should implement this and return the proper Uniform Type Identifier for your file.
*/

+ (NSString *)UTIForFileExport:(id <ResKnifeResource>)resource;

/*!
@method		MIMETypeForFileExport:
@abstract   If you do not know the UTI for your file type, but it has a known MIME Type (e.g. image/svg), you can return that here.
*/

+ (NSString *)MIMETypeForFileExport:(id <ResKnifeResource>)resource;

/*!
@method		OSTypeForFileExport:
@abstract   If your data has a classical Macintosh OSType code, you can return that here.
*/

+ (OSType)OSTypeForFileExport:(id <ResKnifeResource>)resource;

/*!
@method		filenameExtensionForFileExport:
@abstract   As a last resort, you can return here the filename extension for your resource type.
			By default the host application substitutes the resource type if you do not implement this.
*/

+ (NSString *)filenameExtensionForFileExport:(id <ResKnifeResource>)resource;

/*!
@@method		iconForResourceType:
@abstract		Returns the icon to be used throughout the UI for any given resource type.
*/
- (NSImage *)iconForResourceType:(OSType)resourceType;

@end
