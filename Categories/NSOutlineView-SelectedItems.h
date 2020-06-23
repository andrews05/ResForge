#import <Cocoa/Cocoa.h>

@interface NSOutlineView (NGSSelectedItems)

- (nullable id)selectedItem;
- (nonnull NSArray *)selectedItems;

@end
