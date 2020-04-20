#import "OutlineViewDelegate.h"
#import "Resource.h"
#import "ResourceDocument.h"
#import "ResourceDataSource.h"
#import "ResourceNameCell.h"
#import "ApplicationDelegate.h"

@implementation OutlineViewDelegate

- (instancetype)init
{
	self = [super init];
	if(!self) return nil;
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updatePlaceholder:) name:ResourceNameDidChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updatePlaceholder:) name:ResourceTypeDidChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updatePlaceholder:) name:ResourceIDDidChangeNotification object:nil];
	return self;
}

- (void)updatePlaceholder:(NSNotification *)notification
{
	Resource *resource = [notification object];
	ResourceNameCell *cell = (ResourceNameCell *) [[outlineView tableColumnWithIdentifier:@"name"] dataCellForRow:[outlineView rowForItem:resource]];
	if([[resource name] isEqualToString:@""])
	{
		if([resource resID] == -16455)
			[cell setPlaceholderString:NSLocalizedString(@"Custom Icon", nil)];
		else [cell setPlaceholderString:NSLocalizedString(@"Untitled Resource", nil)];
	}
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	if([[tableColumn identifier] isEqualToString:@"size"] || [[tableColumn identifier] isEqualToString:@"attributes"])
		return NO;
	else return YES;
}

/*!
@method		outlineView:willDisplayCell:forTableColumn:item:
@updated	2003-10-25 NGS: Moved functionality of NameFormatter into this method, removed NameFormatter class.
@updated	2003-10-24 NGS: Swapped row colours so first row is white (as per 10.3), conditionalised drawing line background colours to system versions < 10.3, since in 10.3 it is handled by the nib file.
@updated	2003-10-24 NGS: Added iconForResourceType method to app delegate instead of interrogating the cache here.
@pending	remove setting of the cell formatter when that capability is in interface builder
*/

- (void)outlineView:(NSOutlineView *)oView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    if( ![item isKindOfClass: [Resource class]] ) {
        [(ResourceNameCell *)cell setImage:nil];
		return;
    }
	
	Resource *resource = (Resource *)item;
	NSString *identifier = [tableColumn identifier];
	
	// set formatters for cells (remove when IB can set a formatter for an entire table column)
	if([identifier isEqualToString:@"size"])			[cell setFormatter:sizeFormatter];
	else if([identifier isEqualToString:@"attributes"])	[cell setFormatter:attributesFormatter];
	
	// set resource icon
	if([identifier isEqualToString:@"name"])
	{
		if(![resource representedFork])
			[(ResourceNameCell *)cell setImage:[(ApplicationDelegate *)[NSApp delegate] iconForResourceType:[resource type]]];
		else [(ResourceNameCell *)cell setImage:[(ApplicationDelegate *)[NSApp delegate] iconForResourceType:0]];
		
		if([[resource name] isEqualToString:@""])
		{
			// 10.3+ uses placeholder strings
			if([resource resID] == -16455)	// don't bother checking type since there are too many icon types
				[cell setPlaceholderString:NSLocalizedString(@"Custom Icon", nil)];
			else {
				switch (resource.type) {
					case 'carb':
						if (resource.resID == 0) {
							[cell setPlaceholderString:NSLocalizedString(@"Carbon Identifier", nil)];
						} else
							goto notEnum;
						break;
						
					case 'pnot':
						if (resource.resID == 0) {
							[cell setPlaceholderString:NSLocalizedString(@"File Preview", nil)];
						} else
							goto notEnum;
						break;
						
					case 'STR ':
						if (resource.resID == -16396) {
							[cell setPlaceholderString:NSLocalizedString(@"Creator Information", nil)];
						} else
							goto notEnum;
						break;
						
					case 'vers':
						switch (resource.resID) {
							case 1:
								[cell setPlaceholderString:NSLocalizedString(@"File Version", nil)];
								break;
								
							case 2:
								[cell setPlaceholderString:NSLocalizedString(@"Package Version", nil)];
								
								break;
								
							default:
								goto notEnum;
								break;
						}
						
						break;
						
					default:
					notEnum:
						[cell setPlaceholderString:NSLocalizedString(@"Untitled Resource", nil)];
						break;
				}
			}
		}
	}
}

@end

@implementation RKOutlineView

/*!
@method		draggingSourceOperationMaskForLocal:
*/
- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)local
{
    if(local) return NSDragOperationEvery;
    else return NSDragOperationCopy;
}

- (void)keyDown:(NSEvent *)event
{
	NSInteger selectedRow = [self selectedRow];
    if(selectedRow != -1 && [[event characters] isEqualToString:@"\r"]) {
        Resource* resource = [self itemAtRow:selectedRow];
        if ([resource isKindOfClass:[Resource class]] && [resource representedFork] == nil)
            [self editColumn:0 row:selectedRow withEvent:nil select:YES];
    }
	else [super keyDown:event];
}

- (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)selector
{
	// pressed return, end editing
	if(selector == @selector(insertNewline:))
	{
		[[self window] makeFirstResponder:self];
		[self abortEditing];
		return YES;
	}
	
	// pressed tab, move to next editable field
	else if(selector == @selector(insertTab:))
	{
		NSInteger newColumn = ([self editedColumn] +1) % [self numberOfColumns];
		NSString *newColIdentifier = [[self tableColumns][newColumn] identifier];
		if([newColIdentifier isEqualToString:@"size"] || [newColIdentifier isEqualToString:@"attributes"])
		{
			newColumn = (newColumn +1) % [self numberOfColumns];
			newColIdentifier = [[self tableColumns][newColumn] identifier];
			if([newColIdentifier isEqualToString:@"size"] || [newColIdentifier isEqualToString:@"attributes"])
				newColumn = (newColumn +1) % [self numberOfColumns];
		}
		
		[self editColumn:newColumn row:[self selectedRow] withEvent:nil select:YES];
		return YES;
	}
	
	// pressed shift-tab, move to previous editable field
	else if(selector == @selector(insertBacktab:))
	{
		NSInteger newColumn = ([self editedColumn] + [self numberOfColumns] -1) % [self numberOfColumns];
		NSString *newColIdentifier = [[self tableColumns][newColumn] identifier];
		if([newColIdentifier isEqualToString:@"size"] || [newColIdentifier isEqualToString:@"attributes"])
		{
			newColumn = (newColumn + [self numberOfColumns] -1) % [self numberOfColumns];
			newColIdentifier = [[self tableColumns][newColumn] identifier];
			if([newColIdentifier isEqualToString:@"size"] || [newColIdentifier isEqualToString:@"attributes"])
				newColumn = (newColumn + [self numberOfColumns] -1) % [self numberOfColumns];
		}
		
		[self editColumn:newColumn row:[self selectedRow] withEvent:nil select:YES];
		return YES;
	}
	
	return NO;
}

@end
