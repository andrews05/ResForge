#import "ElementHLLG.h"
#import "ElementHBYT.h"

@implementation ElementHLLG

+ (NSFormatter *)sharedFormatter
{
    static HexFormatter *formatter = nil;
    if (!formatter) {
        formatter = [[HexFormatter alloc] init];
        formatter.byteCount = 8;
    }
    return formatter;
}

@end
