#import "CreateResourceSheetController.h"
#import <Carbon/Carbon.h>

@implementation CreateResourceSheetController

- (IBAction)showCreateResourceSheet:(id)sender
{
	[NSApp beginSheet:[self window] modalForWindow:parent modalDelegate:self didEndSelector:NULL contextInfo:nil];
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
		[dataSource addResource:[Resource resourceOfType:[typeView stringValue] andID:[NSNumber numberWithShort:(short) [resIDView intValue]] withName:[nameView stringValue] andAttributes:[NSNumber numberWithUnsignedShort:attributes]]];
	}
	[[self window] orderOut:nil];
	[NSApp endSheet:[self window]];
}

- (IBAction)typePopupSelection:(id)sender
{

}

@end
