#import "QuickDraw.h"
#include "libGraphite/quickdraw/pict.hpp"
#include "libGraphite/quickdraw/cicn.hpp"

@implementation QuickDraw

+ (NSData *)tiffFromPict:(NSData *)data {
    std::vector<char> buffer((char *)data.bytes, (char *)data.bytes+data.length);
    graphite::data::data gData(std::make_shared<std::vector<char>>(buffer), data.length);
    graphite::qd::pict pict(std::make_shared<graphite::data::data>(gData), 0, "");
    return [QuickDraw tiffFromSurface:pict.image_surface().lock()];
}

+ (NSData *)pictFromTiff:(NSData *)tiffData {
    graphite::qd::pict pict([QuickDraw surfaceFromTiff:tiffData]);
    auto data = pict.data();
    return [NSData dataWithBytes:data->get()->data()+data->start() length:data->size()];
}

+ (NSData *)tiffFromCicn:(NSData *)data {
    std::vector<char> buffer((char *)data.bytes, (char *)data.bytes+data.length);
    graphite::data::data gData(std::make_shared<std::vector<char>>(buffer), data.length);
    graphite::qd::cicn cicn(std::make_shared<graphite::data::data>(gData), 0, "");
    return [QuickDraw tiffFromSurface:cicn.surface().lock()];
}

+ (NSData *)cicnFromTiff:(NSData *)tiffData {
    graphite::qd::cicn cicn([QuickDraw surfaceFromTiff:tiffData]);
    auto data = cicn.data();
    return [NSData dataWithBytes:data->get()->data()+data->start() length:data->size()];
}


+ (NSData *)tiffFromSurface:(std::shared_ptr<graphite::qd::surface>)surface {
    auto size = surface->size();
    auto raw = surface->raw();
    unsigned char *ptr = (unsigned char*)raw.data();
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:&ptr
                                                                    pixelsWide:size.width()
                                                                    pixelsHigh:size.height()
                                                                 bitsPerSample:8
                                                               samplesPerPixel:4
                                                                      hasAlpha:YES
                                                                      isPlanar:NO
                                                                colorSpaceName:NSDeviceRGBColorSpace
                                                                   bytesPerRow:size.width()*4
                                                                  bitsPerPixel:32];
    return rep.TIFFRepresentation;
}

+ (std::shared_ptr<graphite::qd::surface>)surfaceFromTiff:(NSData *)tiffData {
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithData:tiffData];
    int length = (int)(rep.size.width * rep.size.height) * 4;
    std::vector<graphite::qd::color> buffer((graphite::qd::color *)rep.bitmapData, (graphite::qd::color *)(rep.bitmapData + length));
    graphite::qd::surface surface((int)rep.size.width, (int)rep.size.height, buffer);
    return std::make_shared<graphite::qd::surface>(surface);
}

@end
