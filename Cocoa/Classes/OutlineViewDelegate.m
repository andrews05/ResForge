#import "OutlineViewDelegate.h"
#import "ResourceNameCell.h"
#import "Resource.h"

@implementation OutlineViewDelegate

- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	if( [[tableColumn identifier] isEqualToString:@"name"] )				[cell setFormatter:nameFormatter];
	else if( [[tableColumn identifier] isEqualToString:@"size"] )			[cell setFormatter:sizeFormatter];
	else if( [[tableColumn identifier] isEqualToString:@"attributes"] )		[cell setFormatter:attributesFormatter];
	
	// alternative to the above three lines, need to profile to find out which is faster
/*	NSTableColumn *nameColumn		= [outlineView tableColumnWithIdentifier:@"name"];
	NSTableColumn *sizeColumn		= [outlineView tableColumnWithIdentifier:@"size"];
	NSTableColumn *attributesColumn	= [outlineView tableColumnWithIdentifier:@"attributes"];
	
	// set text formatters
	if( [tableColumn isEqual:nameColumn] )				[cell setFormatter:nameFormatter];
	else if( [tableColumn isEqual:sizeColumn] )			[cell setFormatter:sizeFormatter];
	else if( [tableColumn isEqual:attributesColumn] )	[cell setFormatter:attributesFormatter];
*/	
	
	// set resource icon
	if( [[tableColumn identifier] isEqualToString:@"name"] )
	{
		[(ResourceNameCell *)cell setImage:[NSImage imageNamed:@"Resource file"]];
//		[(ResourceNameCell *)cell setImage:[[NSWorkspace sharedWorkspace] iconForFileType:[(Resource *)item type]]];
	}
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	return YES;
}

@end
