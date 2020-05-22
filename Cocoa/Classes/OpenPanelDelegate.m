#import "OpenPanelDelegate.h"
#import "../Categories/NGSCategories.h"

@implementation OpenPanelDelegate

- (instancetype)init
{
    if (self = [super init])
        self.formatter = [NSByteCountFormatter new];
    return self;
}

// open panel delegate method
- (void)panelSelectionDidChange:(id)sender
{
    NSURL *url = [sender URL];
    NSNumber *dSize, *tSize;
    [url getResourceValue:&dSize forKey:NSURLFileSizeKey error:nil];
    [url getResourceValue:&tSize forKey:NSURLTotalFileSizeKey error:nil];
    NSInteger dataSize = dSize.integerValue;
    NSInteger rsrcSize = tSize.integerValue - dataSize;
    NSString *dString = dataSize ? [self.formatter stringFromByteCount:dataSize] : @"empty";
    NSString *rString = rsrcSize ? [self.formatter stringFromByteCount:rsrcSize] : @"empty";
    [self.forkSelect removeAllItems];
    [self.forkSelect addItemWithTitle:NSLocalizedString(@"Automatic", nil)];
    [self.forkSelect addItemWithTitle:[NSLocalizedString(@"Data Fork", nil) stringByAppendingFormat:@" (%@)", dString]];
    [self.forkSelect addItemWithTitle:[NSLocalizedString(@"Resource Fork", nil) stringByAppendingFormat:@" (%@)", rString]];
    if (self.forkIndex < self.forkSelect.numberOfItems)
        [self.forkSelect selectItemAtIndex:self.forkIndex];
}

- (NSString *)getSelectedFork
{
    if (!self.readOpenPanelForFork) return nil;
    self.readOpenPanelForFork = NO;
    if (self.forkIndex == 1) return @"";
    if (self.forkIndex == 2) return @"rsrc";
    return nil;
}

@end
