#import "NSOutlineView-SelectedItems.h"

/* The methods in the following catagory were taken from OmniAppKit */

@implementation NSOutlineView (SelectedItems)

- (id)selectedItem
{
	if( [self numberOfSelectedRows] != 1 ) return nil;
	else return [self itemAtRow:[self selectedRow]];
}

- (NSArray *)selectedItems;
{
	NSNumber *row;
	NSMutableArray *items = [NSMutableArray array];
	NSEnumerator *enumerator = [self selectedRowEnumerator];
	
	while( row = [enumerator nextObject] )
		[items addObject:[self itemAtRow:[row intValue]]];
	
	return items;
}

@end