#import "NSOutlineView-SelectedItems.h"

/* The methods in the following catagory were based upon those in OmniAppKit */

@implementation NSOutlineView (NGSSelectedItems)

- (id)selectedItem
{
	if ([self numberOfSelectedRows] != 1) return nil;
	else return [self itemAtRow:[self selectedRow]];
}

- (NSArray *)selectedItems
{
	NSMutableArray *items = [NSMutableArray array];	
	NSIndexSet *indicies = [self selectedRowIndexes];
	[indicies enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
		[items addObject:[self itemAtRow:idx]];
	}];
	
	return items;
}

@end
