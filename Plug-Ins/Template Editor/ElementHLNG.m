#import "ElementHLNG.h"
#import "ElementHBYT.h"

@implementation ElementHLNG

+ (NSFormatter *)sharedFormatter
{
    static HexFormatter *formatter = nil;
    if (!formatter) {
        formatter = [[HexFormatter alloc] init];
        formatter.byteCount = 4;
    }
    return formatter;
}

@end
