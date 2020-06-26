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
- (instancetype)initWithResource:(id <ResKnifeResource>)inResource;


@optional

/*!
@method        dataForFileExport:
@abstract   Return the data to be saved to disk when your resource is exported to a flat file. By default the host application uses the raw resource data if you don't implement this. The idea is that this export function is non-lossy, i.e. only override this if there is a format that is a 100% equivalent to your data.
*/
+ (NSData *)dataForFileExport:(id <ResKnifeResource>)resource;

/*!
@method        exportResource:toURL:
@abstract   Implement this if the plugin needs to be responsible for writing the file itself.
*/
+ (void)exportResource:(id <ResKnifeResource>)resource toURL:(NSURL *)url;

/*!
@method        filenameExtensionForFileExport:
@abstract   You can return here the filename extension for your resource type.
            By default the host application substitutes the resource type if you do not implement this.
*/

+ (NSString *)filenameExtensionForFileExport:(id <ResKnifeResource>)resource;

/*!
@@method        iconForResourceType:
@abstract        Returns the icon to be used throughout the UI for any given resource type.
*/
+ (NSImage *)iconForResourceType:(OSType)resourceType;

@end


/*!
@protocol	ResKnifeTemplatePlugin
@abstract	If you're implementing a template editor, you should implement this extended protocol instead of the regular plugin protocol.
*/
@protocol ResKnifeTemplatePlugin <ResKnifePlugin>

- (instancetype)initWithResource:(id <ResKnifeResource>)inResource template:(id <ResKnifeResource>)tmpl;

@end
