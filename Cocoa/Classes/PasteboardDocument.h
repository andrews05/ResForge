#import <Cocoa/Cocoa.h>
#import "ResourceDocument.h"

@interface PasteboardDocument : ResourceDocument
{
	unsigned long	generalChangeCount;		// change count for the general pasteboard
}

- (void)readPasteboard:(NSString *)pbName;

@end
