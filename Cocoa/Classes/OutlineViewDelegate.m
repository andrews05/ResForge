#import "OutlineViewDelegate.h"
#import "ResourceNameCell.h"

@implementation OutlineViewDelegate

- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	NSTableColumn *nameColumn		= [outlineView tableColumnWithIdentifier:@"name"];
	NSTableColumn *sizeColumn		= [outlineView tableColumnWithIdentifier:@"size"];
	NSTableColumn *attributesColumn	= [outlineView tableColumnWithIdentifier:@"attributes"];
	
	// set text formatters
	if( [tableColumn isEqual:nameColumn] )				[cell setFormatter:nameFormatter];
	else if( [tableColumn isEqual:sizeColumn] )			[cell setFormatter:sizeFormatter];
	else if( [tableColumn isEqual:attributesColumn] )	[cell setFormatter:attributesFormatter];
	
	// set resource icon
	if( [tableColumn isEqual:nameColumn] )
	{
		[(ResourceNameCell *)cell setImage:[NSImage imageNamed:@"Resource file"]];
	}
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	return YES;
}

@end
