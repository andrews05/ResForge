#import "OutlineViewDelegate.h"
#import "Resource.h"
#import "ResourceDataSource.h"
#import "ResourceNameCell.h"
#import "ApplicationDelegate.h"

@implementation OutlineViewDelegate

- (void)tableView:(NSTableView*)tableView didClickTableColumn:(NSTableColumn *)tableColumn
{
	NSArray *oldResources = [(ResourceDataSource *)[tableView dataSource] resources];
	NSArray *newResources;
	
	NSLog( @"Clicked table column: %@", tableColumn );
	
	// sort the array
	if( ![[tableView indicatorImageInTableColumn:tableColumn] isFlipped] )
		newResources = [oldResources sortedArrayUsingFunction:compareResourcesAscending context:(void*)[tableColumn identifier]];
	else
		newResources = [oldResources sortedArrayUsingFunction:compareResourcesDescending context:(void*)[tableColumn identifier]];
	
	// swap new array for old one
	[(ResourceDataSource *)[tableView dataSource] setResources:[NSMutableArray arrayWithArray:newResources]];
	[tableView reloadData];
}

int compareResourcesAscending( Resource *r1, Resource *r2, void *context )
{
	NSString *key = (NSString *)context;
	SEL sel = NSSelectorFromString(key);

	if( [key isEqualToString:@"name"] || [key isEqualToString:@"type"] )
		return [(NSString *)[r1 performSelector:sel] caseInsensitiveCompare: (NSString *)[r2 performSelector:sel]];
	else
		return [(NSNumber *)[r1 performSelector:sel] compare: (NSNumber *)[r2 performSelector:sel]];
}

int compareResourcesDescending( Resource *r1, Resource *r2, void *context )
{
	NSString *key = (NSString *)context;
	SEL sel = NSSelectorFromString(key);

	if( [key isEqualToString:@"name"] || [key isEqualToString:@"type"] )
		return -1 * [(NSString *)[r1 performSelector:sel] caseInsensitiveCompare: (NSString *)[r2 performSelector:sel]];
	else
		return -1 * [(NSNumber *)[r1 performSelector:sel] compare: (NSNumber *)[r2 performSelector:sel]];
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
	
	if( row % 2 )
	{
		[cell setDrawsBackground:NO];
		[cell setBackgroundColor:[NSColor whiteColor]];
	}
	else
	{
		[cell setDrawsBackground:YES];
		[cell setBackgroundColor:[NSColor colorWithCalibratedRed:0.93 green:0.95 blue:1.0 alpha:1.0]];
	}
}

@end