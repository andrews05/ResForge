#import "RKSupportResourceRegistry.h"
#import "Resource.h"
#import "ResourceDocument.h"
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
            [RKSupportResourceRegistry openSupportResourceFile:[path stringByAppendingPathComponent:name]];
	}
}

+ (BOOL)openSupportResourceFile:(NSString *)fileName
{
    OSStatus        error = noErr;
    FSRef           *fileRef = (FSRef *) NewPtrClear(sizeof(FSRef));
    ResFileRefNum   fileRefNum = 0;
    HFSUniStr255    fork;
    
    error = FSPathMakeRef((const UInt8 *)[fileName fileSystemRepresentation], fileRef, nil);
    if (error) return NO;
    
    // Try to open resource fork
    error = FSGetResourceForkName(&fork);
    if (error) return NO;
    error = FSOpenResourceFile(fileRef, fork.length, (UniChar *)fork.unicode, fsRdPerm, &fileRefNum);
    if (error || !fileRefNum) {
        // if opening the resource fork fails, try to open data fork instead
        error = FSGetDataForkName(&fork);
        if (error) return NO;
        error = FSOpenResourceFile(fileRef, fork.length, (UniChar *)fork.unicode, fsRdPerm, &fileRefNum);
        if (error || !fileRefNum) return NO;
    }
    [[Resource supportDataSource] addResources:[ResourceDocument readResourceMap:fileRefNum]];
    FSCloseFork(fileRefNum);
    return YES;
}

@end
