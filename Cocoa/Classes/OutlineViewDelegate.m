#import "OutlineViewDelegate.h"
#import "ResourceNameCell.h"
#import "Resource.h"
#import "ApplicationDelegate.h"

@implementation OutlineViewDelegate

- (void)tableView:(NSTableView*)tableView didClickTableColumn:(NSTableColumn *)tableColumn
{

}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	return YES;
}

- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	int row = [outlineView rowForItem:item];
	NSString *identifier = [tableColumn identifier];
	if( [identifier isEqualToString:@"name"] )				[cell setFormatter:nameFormatter];
	else if( [identifier isEqualToString:@"size"] )			[cell setFormatter:sizeFormatter];
	else if( [identifier isEqualToString:@"attributes"] )	[cell setFormatter:attributesFormatter];
	
	// set resource icon
	if( [identifier isEqualToString:@"name"] )
	{
//		[(ResourceNameCell *)cell setImage:[NSImage imageNamed:@"Resource file"]];
//		[(ResourceNameCell *)cell setImage:[[NSWorkspace sharedWorkspace] iconForFileType:[(Resource *)item type]]];
		[(ResourceNameCell *)cell setImage:[[(ApplicationDelegate *)[NSApp delegate] icons] valueForKey:[(Resource *)item type]]];
	}
	
	if( row % 2 == 0 )	[cell setBackgroundColor:[NSColor whiteColor]];
	else				[cell setBackgroundColor:[NSColor colorWithCalibratedRed:0.93 green:0.95 blue:1.0 alpha:1.0]];
}

@end