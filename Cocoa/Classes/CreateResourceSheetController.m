#import "CreateResourceSheetController.h"
#import "ResourceDataSource.h"
#import "ResourceDocument.h"
#import "Resource.h"

@implementation CreateResourceSheetController

/* -----------------------------------------------------------------------------
	controlTextDidChange:
		Someone changed the control ID edit field. Check whether this is
		a unique ID and appropriately enable the "create" button.
		
		Check "notification" against being nil, which is how we call it when
		we need to explicitly update the enabled state of the "create" button.
		
	
	REVISIONS:
		2003-08-01  UK  Commented, changed to use data source's resourceOfType
						instead of directly messing with the resource list's
						enumerator Removed ID > 0 check -- negative IDs are
						allowed as well.
   -------------------------------------------------------------------------- */

-(void) controlTextDidChange: (NSNotification*)notification
{
	BOOL		enableButton = NO;
	NSString	*type = [typeView stringValue];
	NSNumber	*resID = [NSNumber numberWithInt:[resIDView intValue]];
	
	if( [type length] == 4 )
	{
		// I could use +[Resource getResourceOfType:andID:inDocument:] != nil, but that would be much slower
		Resource *resource = [[document dataSource] resourceOfType:type andID:resID];
		if( resource == nil )   // No resource with that type and ID yet?
			enableButton = YES;
	}
	[createButton setEnabled:enableButton];
}


/* -----------------------------------------------------------------------------
	showCreateResourceSheet:
		Show our sheet and set it up before that.
	
	REVISIONS:
		2003-08-01  UK  Commented, made it "fake" a popup selection so
						type field and popup match. Made it suggest an unused
						resource ID.
   -------------------------------------------------------------------------- */

-(void) showCreateResourceSheet: (ResourceDocument*)sheetDoc
{
	// bug: didEndSelector could be better employed than using the button's targets from interface builder
	document = sheetDoc;
	[NSApp beginSheet:[self window] modalForWindow:[document mainWindow] modalDelegate:self didEndSelector:NULL contextInfo:nil];
	[resIDView setObjectValue: [[document dataSource] uniqueIDForType: [typeView stringValue]]];
	[self typePopupSelection: typePopup];   // Puts current popup value in text field and updates state of "create" button.
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


/* -----------------------------------------------------------------------------
	typePopupSelection:
		Someone chose an item from our "res type" popup menu. Update our
		edit field to show that.
	
	REVISIONS:
		2003-08-01  UK  Commented, made it update state of "create" button..
   -------------------------------------------------------------------------- */

-(IBAction) typePopupSelection:(id)sender
{
	[typeView setStringValue:[typePopup titleOfSelectedItem]];
	[typeView selectText:sender];
	[self controlTextDidChange: nil];   // Make sure "create" button is updated.
}

@end
