#import "RKSupportResourceRegistry.h"

@implementation RKSupportResourceRegistry

+ (void)scanForSupportResources
{
	// TODO: Instead of hard-coding sysPath we should use some FindFolder-like API!
	[RKSupportResourceRegistry scanForSupportResourcesInFolder:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Support Resources"]];
	[RKSupportResourceRegistry scanForSupportResourcesInFolder:[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/ResKnife/Support Resources/"]];
	[RKSupportResourceRegistry scanForSupportResourcesInFolder:[@"/"              stringByAppendingPathComponent:@"Library/Application Support/ResKnife/Support Resources/"]];
}

+ (void)scanForSupportResourcesInFolder:(NSString *)path
{
//	NSLog(@"Looking for resources in %@", path);
	NSEnumerator *enumerator = [[[NSFileManager defaultManager] directoryContentsAtPath:path] objectEnumerator];
	while(NSString *name = [enumerator nextObject])
	{
//		NSLog(@"Examining %@", name);
		if([[name pathExtension] isEqualToString:@"rsrc"])
			[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfFile:[path stringByAppendingPathComponent:name] display:YES];
	}
}

@end
