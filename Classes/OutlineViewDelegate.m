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
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updatePlaceholder:) name:ResourceTypeDidChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updatePlaceholder:) name:ResourceIDDidChangeNotification object:nil];
	return self;
}

- (void)updatePlaceholder:(NSNotification *)notification
{
	Resource *resource = [notification object];
	NSTextFieldCell *cell = [[outlineView tableColumnWithIdentifier:@"name"] dataCellForRow:[outlineView rowForItem:resource]];
    cell.placeholderString = [self resourcePlaceholder:resource];
}

- (NSString *)resourcePlaceholder:(Resource *)resource
{
    if (resource.resID == -16455)    // don't bother checking type since there are too many icon types
        return NSLocalizedString(@"Custom Icon", nil);
    
    switch (resource.type) {
        case 'carb':
            if (resource.resID == 0)
                return NSLocalizedString(@"Carbon Identifier", nil);
            
        case 'pnot':
            if (resource.resID == 0)
                return NSLocalizedString(@"File Preview", nil);
            
        case 'STR ':
            if (resource.resID == -16396)
                return NSLocalizedString(@"Creator Information", nil);
            
        case 'vers':
            switch (resource.resID) {
                case 1:
                    return NSLocalizedString(@"File Version", nil);
                case 2:
                    return NSLocalizedString(@"Package Version", nil);
            }
            
            break;
    }
    return NSLocalizedString(@"Untitled Resource", nil);
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    return [item isKindOfClass:Resource.class];
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
    if ([tableColumn.identifier isEqualToString:@"name"]) {
        if ([item isKindOfClass:Resource.class]) {
            Resource *resource = (Resource *)item;
            
            // set resource icon
            [cell setDrawImage:YES];
            if (![resource representedFork])
                [cell setImage:[(ApplicationDelegate *)[NSApp delegate] iconForResourceType:resource.type]];
            else
                [cell setImage:[(ApplicationDelegate *)[NSApp delegate] iconForResourceType:0]];
            
            [cell setPlaceholderString:[self resourcePlaceholder:resource]];
        } else {
            [cell setDrawImage:NO];
        }
    }
}

@end
