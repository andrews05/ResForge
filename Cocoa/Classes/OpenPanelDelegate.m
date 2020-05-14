#import "OpenPanelDelegate.h"
#import "ApplicationDelegate.h"
#import "../Categories/NGSCategories.h"

@implementation OpenPanelDelegate

- (instancetype)init
{
	if (self = [super init]) {
		_forks = [NSMutableArray new];
		_readOpenPanelForFork = NO;
	}
	return self;
}

- (void)awakeFromNib
{
	// remove this when functionality actually works
	self.addForkButton.enabled = NO;
	self.removeForkButton.enabled = NO;
}

// open panel delegate method
- (void)panelSelectionDidChange:(id)sender
{
	[self.forks setArray:[(ApplicationDelegate *)[NSApp delegate] forksForFile:[[sender filename] createFSRef]]];
	[self.forkTableView reloadData];
}

// table view data source methods
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return self.forks.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	// return object in array
	if (row < self.forks.count) {
        id value = [self.forks[row] objectForKey:tableColumn.identifier];
		if ([tableColumn.identifier isEqualToString:@"forkname"]) {
			HFSUniStr255 resourceForkName = {0};
			OSErr error = FSGetResourceForkName(&resourceForkName);
			
			// return custom names for data and resource forks
            if ([value isEqualToString:@""]) {
				value = NSLocalizedString(@"Data Fork", nil);
            } else if(!error && [value isEqualToString:[NSString stringWithCharacters:resourceForkName.unicode length:resourceForkName.length]]) {
				value = NSLocalizedString(@"Resource Fork", nil);
            }
		}
		
		// return default value otherwise
		return value;
    } else {
        return nil;
    }
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	if ([tableColumn.identifier isEqualToString:@"forkname"]) {
		// update forks array
		// create fork with new name
	}
}

- (IBAction)addFork:(id)sender
{
	// add placeholder to forks array
	[self.forks addObject:@{@"forkname": NSLocalizedString(@"UNTITLED_FORK", nil), @"forksize": @(0), @"forkallocation": @(0)}];
	[self.forkTableView noteNumberOfRowsChanged];
	[self.forkTableView reloadData];
	
	// start editing placeholder
	[self.forkTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:self.forks.count-1] byExtendingSelection:NO];
	[self.forkTableView editColumn:0 row:self.forks.count-1 withEvent:nil select:YES];
}

- (IBAction)removeFork:(id)sender
{
	// display warning
	// delete fork
	
	// update table view
	[self.forks removeObjectAtIndex:self.forkTableView.selectedRow+1];
	[self.forkTableView noteNumberOfRowsChanged];
	[self.forkTableView reloadData];
}

@end
