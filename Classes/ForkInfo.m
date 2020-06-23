#import "ForkInfo.h"

@implementation ForkInfo

- (NSString *)description
{
    if ([self.name isEqualToString:@""])
        return NSLocalizedString(@"Data Fork", nil);
    if ([self.name isEqualToString:@"RESOURCE_FORK"])
        return NSLocalizedString(@"Resource Fork", nil);
    return self.name;
}

+ (NSMutableArray *)forksForFile:(FSRef *)fileRef
{
    if (!fileRef) return nil;
    
    FSCatalogInfo        catalogInfo;
    FSCatalogInfoBitmap whichInfo = kFSCatInfoNodeFlags;
    CatPositionRec        forkIterator = { 0 };
    NSMutableArray *forks = [NSMutableArray new];
    
    // check we have a file, not a folder
    OSErr error = FSGetCatalogInfo(fileRef, whichInfo, &catalogInfo, NULL, NULL, NULL);
    if (!error && !(catalogInfo.nodeFlags & kFSNodeIsDirectoryMask)) {
        // iterate over file and populate forks array
        while (error == noErr) {
            HFSUniStr255 forkName;
            SInt64 forkSize;
            UInt64 forkPhysicalSize;    // used if opening selected fork fails to find empty forks
            
            error = FSIterateForks(fileRef, &forkIterator, &forkName, &forkSize, &forkPhysicalSize);
            if (!error) {
                ForkInfo *fork = [ForkInfo new];
                fork.name = [NSString stringWithCharacters:forkName.unicode length:forkName.length];
                fork.uniName = forkName;
                fork.size = forkSize;
                fork.physicalSize = forkPhysicalSize;
                [forks addObject:fork];
            } else if (error != errFSNoMoreItems) {
                NSLog(@"FSIterateForks() error: %d", error);
            }
        }
    } else if (error) {
        NSLog(@"FSGetCatalogInfo() error: %d", error);
    }
    return forks;
}

@end
