#import "CreateResourceSheetController.h"
#import "ResourceDataSource.h"
#import "ResourceDocument.h"
#import "Resource.h"

@implementation CreateResourceSheetController

- (void)controlTextDidChange:(NSNotification *)notification
{
	BOOL enableButton = NO, clash = NO;
	NSString *type = [typeView stringValue];
	NSNumber *resID = [NSNumber numberWithInt:[resIDView intValue]];
	
	if( [type length] == 4 && [[resIDView stringValue] length] > 0 )
	{
		// I could use +[Resource getResourceOfType:andID:inDocument:] != nil, but that would be much slower
		Resource *resource;
		NSEnumerator *enumerator = [[[document dataSource] resources] objectEnumerator];
		while( resource = [enumerator nextObject] )
		{
			if( [type isEqualToString:[resource type]] && [resID isEqualToNumber:[resource resID]] )
				clash = YES;
		}
		if( !clash ) enableButton = YES;
	}
	[createButton setEnabled:enableButton];
}

- (void)showCreateResourceSheet:(ResourceDocument *)sheetDoc
{
	// bug: didEndSelector could be better employed than using the button's targets from interface builder
	document = sheetDoc;
	[NSApp beginSheet:[self window] modalForWindow:[document mainWindow] modalDelegate:self didEndSelector:NULL contextInfo:nil];
}

- (IBAction)hideCreateResourceSheet:(id)sender
{
	if( sender == createButton )
	{
		unsigned short attributes = 0;
		attributes ^= [[attributesMatrix cellAtRow:0 column:0] intValue]? resPreload:0;
		attributes ^= [[attributesMatrix cellAtRow:1 column:0] intValue]? resPurgeable:0;
		attributes ^= [[attributesMatrix cellAtRow:2 column:0] intValue]? resLocked:0;
		attributes ^= [[attributesMatrix cellAtRow:0 column:1] intValue]? resSysHeap:0;
		attributes ^= [[attributesMatrix cellAtRow:1 column:1] intValue]? resProtected:0;
		
		[[document undoManager] beginUndoGrouping];
		[[document dataSource] addResource:[Resource resourceOfType:[typeView stringValue] andID:[NSNumber numberWithShort:(short) [resIDView intValue]] withName:[nameView stringValue] andAttributes:[NSNumber numberWithUnsignedShort:attributes]]];
		if( [[nameView stringValue] length] == 0 )
			[[document undoManager] setActionName:NSLocalizedString(@"Create Resource", nil)];
		else [[document undoManager] setActionName:[NSString stringWithFormat:NSLocalizedString(@"Create Resource Ò%@Ó", nil), [nameView stringValue]]];
		[[document undoManager] endUndoGrouping];
	}
	[[self window] orderOut:nil];
	[NSApp endSheet:[self window]];
}

- (IBAction)typePopupSelection:(id)sender
{
	[typeView setStringValue:[typePopup titleOfSelectedItem]];
	[typeView selectText:sender];
}

@end
