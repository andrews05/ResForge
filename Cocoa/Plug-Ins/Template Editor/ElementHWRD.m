#import "ElementHWRD.h"
#import "ElementHBYT.h"

@implementation ElementHWRD

+ (NSFormatter *)sharedFormatter
{
    static HexFormatter *formatter = nil;
    if (!formatter) {
        formatter = [[HexFormatter alloc] init];
        formatter.byteCount = 2;
    }
    return formatter;
}

@end
