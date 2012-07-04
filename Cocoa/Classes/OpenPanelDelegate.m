#import "OpenPanelDelegate.h"
#import "ApplicationDelegate.h"
#import "SizeFormatter.h"
#import "../Categories/NSString-FSSpec.h"

@implementation OpenPanelDelegate

- (id)init
{
	self = [super init];
	if(self)
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

- (BOOL)readOpenPanelForFork
{
	return readOpenPanelForFork;
}

- (void)setReadOpenPanelForFork:(BOOL)flag
{
	readOpenPanelForFork = flag;
}

// table view data source methods
- (int)numberOfRowsInTableView:(NSTableView *)tableView
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
			HFSUniStr255 *resourceForkName = (HFSUniStr255 *) NewPtrClear(sizeof(HFSUniStr255));
			OSErr error = FSGetResourceForkName(resourceForkName);
			forkName = [(NSDictionary *)[forks objectAtIndex:row] objectForKey:[tableColumn identifier]];
			
			// return custom names for data and resource forks
			if([forkName isEqualToString:@""])
				forkName = NSLocalizedString(@"Data Fork", nil);
			else if(!error && [forkName isEqualToString:[NSString stringWithCharacters:resourceForkName->unicode length:resourceForkName->length]])
				forkName = NSLocalizedString(@"Resource Fork", nil);
			
			DisposePtr((Ptr) resourceForkName);
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
	[forks addObject:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"UNTITLED_FORK", nil), @"forkname", [NSNumber numberWithInt:0], @"forksize", [NSNumber numberWithInt:0], @"forkallocation", nil]];
	[forkTableView noteNumberOfRowsChanged];
	[forkTableView reloadData];
	
	// start editing placeholder
	[forkTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:[forks count]-1] byExtendingSelection:NO];
	[forkTableView editColumn:0 row:[forks count]-1 withEvent:nil select:YES];
}

- (IBAction)removeFork:(id)sender
{
	// display warning
	// delete fork
	
	// update table view
	[forks removeObjectAtIndex:[forkTableView selectedRow]+1];
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

- (NSTableView *)forkTableView
{
	return forkTableView;
}

@end