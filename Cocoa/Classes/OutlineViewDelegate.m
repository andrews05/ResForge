#import "OutlineViewDelegate.h"
#import "Resource.h"
#import "ResourceDataSource.h"
#import "ResourceNameCell.h"
#import "ApplicationDelegate.h"

@implementation OutlineViewDelegate

- (void)tableView:(NSTableView*)tableView didClickTableColumn:(NSTableColumn *)tableColumn
{
	NSArray *newResources;
	NSArray *oldResources = [(ResourceDataSource *)[tableView dataSource] resources];
	
	// sort the array
	NSImage *indicator = [tableView indicatorImageInTableColumn:tableColumn];
	NSImage *upArrow = [NSTableView _defaultTableHeaderSortImage];
	if( indicator == upArrow )
	{
		newResources = [oldResources sortedArrayUsingFunction:compareResourcesAscending context:(void*)[tableColumn identifier]];
	}
	else
	{
		newResources = [oldResources sortedArrayUsingFunction:compareResourcesDescending context:(void*)[tableColumn identifier]];
	}
	
	// swap new array for old one
	[(ResourceDataSource *)[tableView dataSource] setResources:[NSMutableArray arrayWithArray:newResources]];
	[tableView reloadData];
}

int compareResourcesAscending( Resource *r1, Resource *r2, void *context )
{
	NSString *key = (NSString *)context;
	SEL sel = NSSelectorFromString(key);

	if( [key isEqualToString:@"name"] || [key isEqualToString:@"type"] )
	{
		// compare two NSStrings (case-insensitive)
		return [(NSString *)[r1 performSelector:sel] caseInsensitiveCompare: (NSString *)[r2 performSelector:sel]];
	}
	else
	{
		// compare two NSNumbers (or any other class)
		return [(NSNumber *)[r1 performSelector:sel] compare: (NSNumber *)[r2 performSelector:sel]];
	}
}

int compareResourcesDescending( Resource *r1, Resource *r2, void *context )
{
	NSString *key = (NSString *)context;
	SEL sel = NSSelectorFromString(key);

	if( [key isEqualToString:@"name"] || [key isEqualToString:@"type"] )
	{
		// compare two NSStrings (case-insensitive)
		return -1 * [(NSString *)[r1 performSelector:sel] caseInsensitiveCompare: (NSString *)[r2 performSelector:sel]];
	}
	else
	{
		// compare two NSNumbers (or any other class)
		return -1 * [(NSNumber *)[r1 performSelector:sel] compare: (NSNumber *)[r2 performSelector:sel]];
	}
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

@implementation NSOutlineView (OutlineSortView)

- (void)swapForOutlineSortView
{
	isa = [OutlineSortView class];
}

@end

@implementation OutlineSortView

- (void)keyDown:(NSEvent *)event
{
	if( [self selectedRow] != -1 && [[event characters] isEqualToString:[NSString stringWithCString:"\r"]] )
		[self editColumn:0 row:[self selectedRow] withEvent:nil select:YES];
	else [super keyDown:event];
}

- (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)selector
{
	// pressed return, end editing
	if( selector == @selector(insertNewline:) )
	{
		[[self window] makeFirstResponder:self];
		[self abortEditing];
		return YES;
	}
	
	// pressed tab, move to next editable field
	else if( selector == @selector(insertTab:) )
	{
		int newColumn = ([self editedColumn] +1) % [self numberOfColumns];
		NSString *newColIdentifier = [[[self tableColumns] objectAtIndex:newColumn] identifier];
		if( [newColIdentifier isEqualToString:@"size"] || [newColIdentifier isEqualToString:@"attributes"] )
		{
			newColumn = (newColumn +1) % [self numberOfColumns];
			newColIdentifier = [[[self tableColumns] objectAtIndex:newColumn] identifier];
			if( [newColIdentifier isEqualToString:@"size"] || [newColIdentifier isEqualToString:@"attributes"] )
				newColumn = (newColumn +1) % [self numberOfColumns];
		}
		
		[self editColumn:newColumn row:[self selectedRow] withEvent:nil select:YES];
		return YES;
	}
	
	// pressed shift-tab, move to previous editable field
	else if( selector == @selector(insertBacktab:) )
	{
		int newColumn = ([self editedColumn] + [self numberOfColumns] -1) % [self numberOfColumns];
		NSString *newColIdentifier = [[[self tableColumns] objectAtIndex:newColumn] identifier];
		if( [newColIdentifier isEqualToString:@"size"] || [newColIdentifier isEqualToString:@"attributes"] )
		{
			newColumn = (newColumn + [self numberOfColumns] -1) % [self numberOfColumns];
			newColIdentifier = [[[self tableColumns] objectAtIndex:newColumn] identifier];
			if( [newColIdentifier isEqualToString:@"size"] || [newColIdentifier isEqualToString:@"attributes"] )
				newColumn = (newColumn + [self numberOfColumns] -1) % [self numberOfColumns];
		}
		
		[self editColumn:newColumn row:[self selectedRow] withEvent:nil select:YES];
		return YES;
	}
	
	return NO;
}

//- (void)_sendDelegateDidMouseDownInHeader:(int)columnIndex
- (void)_sendDelegateDidClickColumn:(int)columnIndex
{
	NSTableColumn *tableColumn = [[self tableColumns] objectAtIndex:columnIndex];
	NSImage *indicator = [self indicatorImageInTableColumn:tableColumn];
	NSImage *upArrow = [NSTableView _defaultTableHeaderSortImage];
	NSImage *downArrow = [NSTableView _defaultTableHeaderReverseSortImage];
	if( indicator )
	{
		// column already selected
		if( indicator == upArrow )
			[self setIndicatorImage:downArrow inTableColumn:tableColumn];
		else [self setIndicatorImage:upArrow inTableColumn:tableColumn];
	}
	else
	{
		// new column selected
		if( [self highlightedTableColumn] != nil )
		{
			// if there is an existing selection, clear it's image
			[self setIndicatorImage:nil inTableColumn:[self highlightedTableColumn]];
		}
		
		if( [[tableColumn identifier] isEqualToString:@"name"] || [[tableColumn identifier] isEqualToString:@"type"] )
		{
			// sort name and type columns ascending by default
			[self setIndicatorImage:upArrow inTableColumn:tableColumn];
		}
		else
		{
			// sort all other columns descending by default
			[self setIndicatorImage:downArrow inTableColumn:tableColumn];
		}
		[self setHighlightedTableColumn:tableColumn];
	}
	[[self delegate] tableView:self didClickTableColumn:tableColumn];
}

@end