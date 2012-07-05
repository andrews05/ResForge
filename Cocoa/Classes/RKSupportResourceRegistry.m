#import "RKSupportResourceRegistry.h"
#import "../Categories/NGSCategories.h"

@implementation RKSupportResourceRegistry

+ (void)scanForSupportResources
{
	[RKSupportResourceRegistry scanForSupportResourcesInFolder:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Support Resources"]];
#if MAC_OS_X_VERSION_10_4 <= MAC_OS_X_VERSION_MAX_ALLOWED
	NSArray *dirsArray = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSAllDomainsMask, YES);
	dirsArray = [dirsArray arrayByMakingObjectsPerformSelector:@selector(stringByAppendingPathComponent:) withObject:@"ResKnife/Support Resources"];
	// FIXME: log content of dirsArray and merge with the following:
	for (NSString *dir in dirsArray)
		[RKSupportResourceRegistry scanForSupportResourcesInFolder:dir];
#else
	[RKSupportResourceRegistry scanForSupportResourcesInFolder:[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/ResKnife/Support Resources"]];
	[RKSupportResourceRegistry scanForSupportResourcesInFolder:@"/Library/Application Support/ResKnife/Support Resources"];
	[RKSupportResourceRegistry scanForSupportResourcesInFolder:@"/Network/Library/Application Support/ResKnife/Support Resources"];
#endif
}

+ (void)scanForSupportResourcesInFolder:(NSString *)path
{
//	NSLog(@"Looking for resources in %@", path);
	NSString *name;
	NSEnumerator *enumerator = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil] objectEnumerator];
	while(name = [enumerator nextObject])
	{
//		NSLog(@"Examining %@", name);
		if([[name pathExtension] isEqualToString:@"rsrc"])
			// FIXME: this method was deprecated in 10.4 in favour of - (id)openDocumentWithContentsOfURL:(NSURL *)absoluteURL display:(BOOL)displayDocument error:(NSError **)outError;
			[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:[NSURL fileURLWithPath:[path stringByAppendingPathComponent:name]] display:YES];
	}
}

@end
