#import "RKSupportResourceRegistry.h"
#import "../Categories/NGSCategories.h"

@implementation RKSupportResourceRegistry

+ (void)scanForSupportResources
{
	[RKSupportResourceRegistry scanForSupportResourcesInFolder:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Support Resources"]];
	NSArray *dirsArray = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSAllDomainsMask, YES);
	{
		NSMutableArray *tmparray = [[NSMutableArray alloc] initWithCapacity:[dirsArray count]];
		for (NSString *dir in dirsArray) {
			[tmparray addObject:[dir stringByAppendingPathComponent:@"ResKnife/Support Resources"]];
		}
		dirsArray = [[NSArray alloc] initWithArray:tmparray];
	}
	// FIXME: log content of dirsArray and merge with the following:
	for (NSString *dir in dirsArray)
		[RKSupportResourceRegistry scanForSupportResourcesInFolder:dir];
}

+ (void)scanForSupportResourcesInFolder:(NSString *)path
{
	// NSLog(@"Looking for resources in %@", path);
	NSString *name;
	NSEnumerator *enumerator = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil] objectEnumerator];
	while(name = [enumerator nextObject])
	{
		// NSLog(@"Examining %@", name);
		if([[name pathExtension] isEqualToString:@"rsrc"])
			// FIXME: this method was deprecated in 10.7 in favour of - (void)openDocumentWithContentsOfURL:(NSURL *)url display:(BOOL)displayDocument completionHandler:(void (^)(NSDocument *document, BOOL documentWasAlreadyOpen, NSError *error))completionHandler;
			[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:[NSURL fileURLWithPath:[path stringByAppendingPathComponent:name]] display:YES error:NULL];
	}
}

@end
