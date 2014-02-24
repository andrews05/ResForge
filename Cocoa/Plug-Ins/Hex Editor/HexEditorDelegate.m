#import "HexEditorDelegate.h"
#import "HexWindowController.h"
#import "HexTextView.h"

@implementation HexEditorDelegate

- (id)init
{
	self = [super init];
	if(!self) return nil;
	
	editedLow = NO;
	return self;
}

- (void)awakeFromNib
{
	// - MOVED TO HEX WINDOW CONTROLLER DUE TO BUG IN IB MEANING OFFSET, HEX AND ASCII AREN'T SET AT THIS TIME
	
	// notify me when a view scrolls so I can update the other two
//	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewDidScroll:) name:NSViewBoundsDidChangeNotification object:[[offset enclosingScrollView] contentView]];
//	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewDidScroll:) name:NSViewBoundsDidChangeNotification object:[[hex enclosingScrollView] contentView]];
//	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewDidScroll:) name:NSViewBoundsDidChangeNotification object:[[ascii enclosingScrollView] contentView]];
}

/* REMOVE THESE WHEN I.B. IS FIXED */
- (void)setHex:(id)newView
{
	hex = newView;
}

- (void)setAscii:(id)newView
{
	ascii = newView;
}
/* END REMOVE MARKER */

/* data re-representation methods */

- (NSString *)offsetRepresentation:(NSData *)data
{
	NSInteger dataLength = [data length], bytesPerRow = [controller bytesPerRow];
	NSInteger rows = (dataLength / bytesPerRow) + ((dataLength % bytesPerRow)? 1:0);
	NSMutableString *representation = [NSMutableString string];
	NSInteger	row;
	
	for( row = 0; row < rows; row++ )
		[representation appendFormat:@"%08lX:", (unsigned long)(row * bytesPerRow)];
	
	return representation;
}

/* delegation methods */

- (void)viewDidScroll:(NSNotification *)notification
{
	// get object refs for increased speed
	NSClipView *object		= (NSClipView *) [notification object];
	NSClipView *offsetClip	= [[offset enclosingScrollView] contentView];
	NSClipView *hexClip		= [[hex enclosingScrollView] contentView];
	NSClipView *asciiClip	= [[ascii enclosingScrollView] contentView];
	
	// remove observer to stop myself from receiving bounds changed notifications (n.b. -setPostsBoundsChangedNotifications: only suspends them temporarilly - you get a unified bounds changed notification upon enabling it again and is designed for live resizing and such, so of no use here)
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSViewBoundsDidChangeNotification object:nil];
	
	// when a view scrolls, update the other two
	if( object != offsetClip )	[offsetClip setBoundsOrigin:[object bounds].origin];
	if( object != hexClip )		[hexClip setBoundsOrigin:[object bounds].origin];
	if( object != asciiClip )	[asciiClip setBoundsOrigin:[object bounds].origin];
	
	// restore notifications
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewDidScroll:) name:NSViewBoundsDidChangeNotification object:offsetClip];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewDidScroll:) name:NSViewBoundsDidChangeNotification object:hexClip];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewDidScroll:) name:NSViewBoundsDidChangeNotification object:asciiClip];
}

- (NSRange)textView:(NSTextView *)textView willChangeSelectionFromCharacterRange:(NSRange)oldSelectedCharRange toCharacterRange:(NSRange)newSelectedCharRange
{
	NSRange hexRange, asciiRange, byteRange = NSMakeRange(0,0);
	
	// temporarilly removing the delegate stops this function being called recursivly!
	id oldDelegate = [hex delegate];
	[hex setDelegate:nil];
	[ascii setDelegate:nil];
	
	if( textView == hex )			// we're selecting hexadecimal
	{
		byteRange = [HexWindowController byteRangeFromHexRange:newSelectedCharRange];
		asciiRange = [HexWindowController asciiRangeFromByteRange:byteRange];
		[ascii setSelectedRange:asciiRange];
	}
	else if( textView == ascii )	// we're selecting ASCII
	{
		byteRange = [HexWindowController byteRangeFromAsciiRange:newSelectedCharRange];
		hexRange = [HexWindowController hexRangeFromByteRange:byteRange];
		[hex setSelectedRange:hexRange];
	}
	
	// put the new selection into the message bar
	[message setStringValue:[NSString stringWithFormat:@"Current selection: %@", NSStringFromRange(byteRange)]];
	
	// restore delegates
	[hex setDelegate:oldDelegate];
	[ascii setDelegate:oldDelegate];
	return newSelectedCharRange;
}

- (HexWindowController *)controller
{
	return controller;
}

- (NSTextView *)hex
{
	return hex;
}

- (NSTextView *)ascii
{
	return ascii;
}

- (BOOL)editedLow
{
	return editedLow;
}

- (void)setEditedLow:(BOOL)flag
{
	editedLow = flag;
}

- (NSRange)rangeForUserTextChange
{
	// if editing hex, convert hex selection to byte selection
	if( [[controller window] firstResponder] == hex )
		rangeForUserTextChange = [HexWindowController byteRangeFromHexRange:[hex rangeForUserTextChange]];
	
	// if editing ascii, convert ascii selection to byte selection
	else if( [[controller window] firstResponder] == ascii )
		rangeForUserTextChange = [HexWindowController byteRangeFromAsciiRange:[ascii rangeForUserTextChange]];
	
	return rangeForUserTextChange;
}

@end
