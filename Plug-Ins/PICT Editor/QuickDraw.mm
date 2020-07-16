#import "QuickDraw.h"
#include "libGraphite/quickdraw/pict.hpp"

@implementation QuickDraw

+ (NSData *)tiffFromPict:(NSData *)pictData {
    std::vector<char> buffer((char *)pictData.bytes, (char *)pictData.bytes+pictData.length);
    graphite::data::data data(std::make_shared<std::vector<char>>(buffer), pictData.length);
    graphite::qd::pict pict(std::make_shared<graphite::data::data>(data), 0, "");
    auto size = pict.image_surface().lock()->size();
    auto raw = pict.image_surface().lock()->raw();
    unsigned char *ptr = (unsigned char*)raw.data();
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:&ptr
                                                                    pixelsWide:size.width()
                                                                    pixelsHigh:size.height()
                                                                 bitsPerSample:8
                                                               samplesPerPixel:4
                                                                      hasAlpha:YES
                                                                      isPlanar:NO
                                                                colorSpaceName:NSCalibratedRGBColorSpace
                                                                   bytesPerRow:size.width()*4
                                                                  bitsPerPixel:32];
    return rep.TIFFRepresentation;
}

+ (NSData *)pictFromTiff:(NSData *)tiffData {
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithData:tiffData];
    int length = (int)(rep.size.width * rep.size.height) * 4;
    std::vector<graphite::qd::color> buffer((graphite::qd::color *)rep.bitmapData, (graphite::qd::color *)(rep.bitmapData + length));
    graphite::qd::surface surface((int)rep.size.width, (int)rep.size.height, buffer);
    graphite::qd::pict pict(std::make_shared<graphite::qd::surface>(surface));
    auto data = pict.data();
    return [NSData dataWithBytes:data->get()->data()+data->start() length:data->size()];
}

@end
