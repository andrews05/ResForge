#import "OpenPanelDelegate.h"
#import "ApplicationDelegate.h"
#import "../Categories/NSString-FSSpec.h"

@implementation OpenPanelDelegate
@synthesize forkTableView;
@synthesize readOpenPanelForFork;

- (id)init
{
	if(self = [super init])
	{
		forks = [[NSMutableArray alloc] init];
		readOpenPanelForFork = NO;
	}
	return self;
}

- (void)awakeFromNib
{
	// remove this when functionality actually works
	[addForkButton setEnabled:NO];
	[removeForkButton setEnabled:NO];
}

- (void)dealloc
{
	[forks release];
	[super dealloc];
}

// open panel delegate method
- (void)panelSelectionDidChange:(id)sender
{
	[forks setArray:[(ApplicationDelegate *)[NSApp delegate] forksForFile:[[sender filename] createFSRef]]];
	[forkTableView reloadData];
}

// table view data source methods
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [forks count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	// return object in array
	if(row < [forks count])
	{
		if([[tableColumn identifier] isEqualToString:@"forkname"])
		{
			NSString *forkName = nil;
			HFSUniStr255 resourceForkName = {0};
			OSErr error = FSGetResourceForkName(&resourceForkName);
			forkName = [(NSDictionary *)[forks objectAtIndex:row] objectForKey:[tableColumn identifier]];
			
			// return custom names for data and resource forks
			if([forkName isEqualToString:@""])
				forkName = NSLocalizedString(@"Data Fork", nil);
			else if(!error && [forkName isEqualToString:[NSString stringWithCharacters:resourceForkName.unicode length:resourceForkName.length]])
				forkName = NSLocalizedString(@"Resource Fork", nil);
			
			return forkName;
		}
		
		// return default value otherwise
		return [(NSDictionary *)[forks objectAtIndex:row] objectForKey:[tableColumn identifier]];
	}
	else return nil;
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	if([[tableColumn identifier] isEqualToString:@"forkname"])
	{
		// update forks array
		// create fork with new name
	}
}

- (IBAction)addFork:(id)sender
{
	// add placeholder to forks array
	[forks addObject:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"UNTITLED_FORK", nil), @"forkname", @(0), @"forksize", @(0), @"forkallocation", nil]];
	[forkTableView noteNumberOfRowsChanged];
	[forkTableView reloadData];
	
	// start editing placeholder
	[forkTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:[forks count]-1] byExtendingSelection:NO];
	[forkTableView editColumn:0 row:[forks count] - 1 withEvent:nil select:YES];
}

- (IBAction)removeFork:(id)sender
{
	// display warning
	// delete fork
	
	// update table view
	[forks removeObjectAtIndex:[forkTableView selectedRow] + 1];
	[forkTableView noteNumberOfRowsChanged];
	[forkTableView reloadData];
}

- (NSArray *)forks
{
	// returns an immutable array
	return [NSArray arrayWithArray:forks];
}

- (NSView *)openPanelAccessoryView
{
	return openPanelAccessoryView;
}

@end
