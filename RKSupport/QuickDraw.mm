#import "QuickDraw.h"
#include "libGraphite/quickdraw/pict.hpp"
#include "libGraphite/quickdraw/cicn.hpp"
#include "libGraphite/quickdraw/ppat.hpp"

@implementation QuickDraw

+ (NSData *)tiffFromPict:(NSData *)data {
    std::vector<char> buffer((char *)data.bytes, (char *)data.bytes+data.length);
    graphite::data::data gData(std::make_shared<std::vector<char>>(buffer), data.length);
    try {
        graphite::qd::pict pict(std::make_shared<graphite::data::data>(gData), 0, "");
        return [QuickDraw tiffFromSurface:pict.image_surface().lock()];
    } catch (const std::exception& e) {
        return nil;
    }
}

+ (NSData *)pictFromRep:(NSBitmapImageRep *)rep {
    graphite::qd::pict pict([QuickDraw surfaceFromRep:rep]);
    auto data = pict.data();
    return [NSData dataWithBytes:data->get()->data()+data->start() length:data->size()];
}

+ (NSData *)tiffFromCicn:(NSData *)data {
    std::vector<char> buffer((char *)data.bytes, (char *)data.bytes+data.length);
    graphite::data::data gData(std::make_shared<std::vector<char>>(buffer), data.length);
    try {
        graphite::qd::cicn cicn(std::make_shared<graphite::data::data>(gData), 0, "");
        return [QuickDraw tiffFromSurface:cicn.surface().lock()];
    } catch (const std::exception& e) {
        return nil;
    }
}

+ (NSData *)cicnFromRep:(NSBitmapImageRep *)rep {
    graphite::qd::cicn cicn([QuickDraw surfaceFromRep:rep]);
    auto data = cicn.data();
    return [NSData dataWithBytes:data->get()->data()+data->start() length:data->size()];
}

+ (NSData *)tiffFromPpat:(NSData *)data {
    std::vector<char> buffer((char *)data.bytes, (char *)data.bytes+data.length);
    graphite::data::data gData(std::make_shared<std::vector<char>>(buffer), data.length);
    try {
        graphite::qd::ppat ppat(std::make_shared<graphite::data::data>(gData), 0, "");
        return [QuickDraw tiffFromSurface:ppat.surface().lock()];
    } catch (const std::exception& e) {
        return nil;
    }
}

+ (NSData *)ppatFromRep:(NSBitmapImageRep *)rep {
    graphite::qd::ppat ppat([QuickDraw surfaceFromRep:rep]);
    auto data = ppat.data();
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

+ (std::shared_ptr<graphite::qd::surface>)surfaceFromRep:(NSBitmapImageRep *)rep {
    int length = (int)(rep.pixelsWide * rep.pixelsHigh) * 4;
    std::vector<graphite::qd::color> buffer((graphite::qd::color *)rep.bitmapData, (graphite::qd::color *)(rep.bitmapData + length));
    graphite::qd::surface surface((int)rep.pixelsWide, (int)rep.pixelsHigh, buffer);
    return std::make_shared<graphite::qd::surface>(surface);
}

@end
