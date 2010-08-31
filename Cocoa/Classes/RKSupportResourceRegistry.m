#import "RKSupportResourceRegistry.h"
#import "../Categories/NGSCategories.h"

@implementation RKSupportResourceRegistry

+ (void)scanForSupportResources
{
#if MAC_OS_X_VERSION_10_4 <= MAC_OS_X_VERSION_MAX_ALLOWED
	NSArray *dirsArray = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSAllDomainsMask, YES);
	dirsArray = [dirsArray arrayByMakingObjectsPerformSelector:@selector(stringByAppendingPathComponent:) withObject:@"ResKnife/Support Resources"];
	// FIXME: log content of dirsArray and merge with the following:
#endif
	[RKSupportResourceRegistry scanForSupportResourcesInFolder:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Support Resources"]];
	[RKSupportResourceRegistry scanForSupportResourcesInFolder:[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/ResKnife/Support Resources"]];
	[RKSupportResourceRegistry scanForSupportResourcesInFolder:@"/Library/Application Support/ResKnife/Support Resources"];
	[RKSupportResourceRegistry scanForSupportResourcesInFolder:@"/Network/Library/Application Support/ResKnife/Support Resources"];
}

+ (void)scanForSupportResourcesInFolder:(NSString *)path
{
//	NSLog(@"Looking for resources in %@", path);
	NSString *name;
	NSEnumerator *enumerator = [[[NSFileManager defaultManager] directoryContentsAtPath:path] objectEnumerator];
	while(name = [enumerator nextObject])
	{
//		NSLog(@"Examining %@", name);
		if([[name pathExtension] isEqualToString:@"rsrc"])
			// FIXME: this method was deprecated in 10.4 in favour of - (id)openDocumentWithContentsOfURL:(NSURL *)absoluteURL display:(BOOL)displayDocument error:(NSError **)outError;
			[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfFile:[path stringByAppendingPathComponent:name] display:YES];
	}
}

@end
