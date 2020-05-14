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
    NSInteger index = self.forkIndex;
    self.forks = [ForkInfo forksForFile:[[sender filename] createFSRef]];
    [self.forkSelect removeAllItems];
    [self.forkSelect addItemWithTitle:NSLocalizedString(@"Automatic", nil)];
    for (ForkInfo *fork in self.forks) {
        NSString *size = fork.size ? [self.formatter stringFromByteCount:fork.size] : @"empty";
        [self.forkSelect addItemWithTitle:[fork.description stringByAppendingFormat:@" (%@)", size]];
    }
    if (index < self.forkSelect.numberOfItems)
        [self.forkSelect selectItemAtIndex:index];
}

- (ForkInfo *)getSelectedFork
{
    if (!self.readOpenPanelForFork) return nil;
    self.readOpenPanelForFork = NO;
    if (!self.forkIndex) return nil;
    return self.forks[self.forkIndex-1];
}

@end
