#import "OutlineViewDelegate.h"
#import "ResourceNameCell.h"
#import "Resource.h"

@implementation OutlineViewDelegate

- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	NSString *identifier = [tableColumn identifier];
	if( [identifier isEqualToString:@"name"] )				[cell setFormatter:nameFormatter];
	else if( [identifier isEqualToString:@"size"] )			[cell setFormatter:sizeFormatter];
	else if( [identifier isEqualToString:@"attributes"] )	[cell setFormatter:attributesFormatter];
	
	// set resource icon
	if( [identifier isEqualToString:@"name"] )
	{
//		[(ResourceNameCell *)cell setImage:[NSImage imageNamed:@"Resource file"]];
		[(ResourceNameCell *)cell setImage:[[NSWorkspace sharedWorkspace] iconForFileType:[(Resource *)item type]]];
	}
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	return YES;
}

@end