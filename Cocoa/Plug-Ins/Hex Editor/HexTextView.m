#import "HexTextView.h"

@implementation HexTextView

- (void)insertText:(id)insertString
{
	NSLog( insertString );
	[super insertText:insertString];
}

- (void)setSelectedRange:(NSRange)charRange affinity:(NSSelectionAffinity)affinity stillSelecting:(BOOL)flag
{
	NSRange newRange = charRange;
	
	// select whole bytes at a time (only if selecting in hex!)
	if( self == [[self delegate] hex] )
	{
		newRange = [self selectionRangeForProposedRange:charRange
			granularity:NSSelectByWord];
//		newRange.location -= newRange.location % 3;
//		newRange.length -= (newRange.length % 3) -2;
		NSLog( @"hex selection changed to %@", NSStringFromRange(newRange) );
	}
	
	// call the superclass to update the selection
	[super setSelectedRange:newRange affinity:affinity stillSelecting:NO];
}

@end
