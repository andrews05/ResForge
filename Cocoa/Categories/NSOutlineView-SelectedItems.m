#import "NSOutlineView-SelectedItems.h"

/* The methods in the following catagory were based upon those in OmniAppKit */

@implementation NSOutlineView (RKSelectedItemExtensions)

- (id)selectedItem
{
	if ([self numberOfSelectedRows] != 1) return nil;
	else return [self itemAtRow:[self selectedRow]];
}

- (NSArray *)selectedItems
{
	NSMutableArray *items = [NSMutableArray array];
#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_3
	NSIndexSet *indicies = [self selectedRowIndexes];
    unsigned int rowIndex = [indicies firstIndex];
    while (rowIndex != NSNotFound)
	{
        [items addObject:[self itemAtRow:rowIndex]];
        rowIndex = [indicies indexGreaterThanIndex:rowIndex];
    }
#else
	NSNumber *row;
	NSEnumerator *enumerator = [self selectedRowEnumerator];
	while (row = [enumerator nextObject])
		[items addObject:[self itemAtRow:[row intValue]]];
#endif
	
	return items;
}

@end