#import "HexTextView.h"
#import "ResKnifeResourceProtocol.h"

@implementation HexTextView

- (void)insertText:(id)insertString
{
	// bug: Every time a character is typed or string pasted, the entire resource is duplicated, operated on and disposed of! Perhaps I could do this in a better way?
	NSMutableData *newData = [NSMutableData dataWithData:[[[self window] windowController] data]];
	NSRange selection = [self selectedRange];
	
	NSLog( insertString );
	// modify resource data
	
	// update resource data - this causes a notification to be sent out, which the plug receives and acts upon to update the text views
	[(id <ResKnifeResourceProtocol>)[[[self window] windowController] resource] setData:newData];
}

- (void)setSelectedRange:(NSRange)charRange affinity:(NSSelectionAffinity)affinity stillSelecting:(BOOL)flag
{
	NSRange newRange = charRange;
	
	// select whole bytes at a time (only if selecting in hex!)
	if( self == (id) [[self delegate] hex] )
	{
//		NSLog( NSStringFromRange(newRange) );
		
		// move selection offset to beginning of byte
		newRange.location -= (charRange.location % 3);
		newRange.length += (charRange.location % 3);
		
		// set selection length to whole number of bytes
		if( charRange.length != 0 )
			newRange.length -= (newRange.length % 3) -2;
		else newRange.length = 0;
		
		// move insertion point to next byte if needs be
		if( newRange.location == charRange.location -1 && newRange.length == 0 )
			newRange.location += 3;
		
//		NSLog( NSStringFromRange(newRange) );
//		NSLog( @"===========" );
	}
	// select return character if selecting ascii
	else if( self == (id) [[self delegate] ascii] )
	{
		// if ascii selection goes up to sixteenth byte on last line, select return character too
		if( (charRange.length + charRange.location) % 17 == 16)
		{
			// if selection is zero bytes long, move insertion point to character after return
			if( charRange.length == 0 )
			{
				// if moving back from first byte of line to previous line, skip return char
				NSRange selected = [self selectedRange];
				if( (selected.length + selected.location) % 17 == 0 )
					newRange.location -= 1;
				else newRange.location += 1;
			}
			else newRange.length += 1;
		}
	}
	
	// call the superclass to update the selection
	[super setSelectedRange:newRange affinity:affinity stillSelecting:NO];
}

@end
