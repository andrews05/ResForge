#import "RKSupportResourceRegistry.h"
#import "Resource.h"
#import "ResourceDocument.h"
#import "../Categories/NGSCategories.h"

@implementation RKSupportResourceRegistry

+ (void)scanForSupportResources
{
    [RKSupportResourceRegistry scanForSupportResourcesInBundle:[NSBundle mainBundle]];
	NSArray *dirsArray = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSAllDomainsMask];
    for (NSURL *dir in dirsArray) {
        NSArray *paths = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:dir includingPropertiesForKeys:nil options:0 error:nil];
        for (NSURL *name in paths) {
            if ([name.pathExtension isEqualToString:@"rsrc"])
                [RKSupportResourceRegistry openSupportResourceFile:name];
        }
    }
}

+ (void)scanForSupportResourcesInBundle:(NSBundle *)bundle
{
    NSArray *urls = [bundle URLsForResourcesWithExtension:@"rsrc" subdirectory:@"Support Resources"];
    for (NSURL *url in urls)
        [RKSupportResourceRegistry openSupportResourceFile:url];
}

+ (BOOL)openSupportResourceFile:(NSURL *)fileName
{
    [[Resource supportDataSource] addResources:[ResourceDocument readResourceMap:fileName document:nil]];
    return YES;
}

@end
