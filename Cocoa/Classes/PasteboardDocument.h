#import <Cocoa/Cocoa.h>
#import "ResourceDocument.h"

@interface PasteboardDocument : ResourceDocument
{
	int		generalChangeCount;		// change count for the general pasteboard
}

- (void)readPasteboard:(NSString *)pbName;

@end
