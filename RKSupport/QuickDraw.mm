#import "QuickDraw.h"
#include "libGraphite/quickdraw/pict.hpp"
#include "libGraphite/quickdraw/cicn.hpp"
#include "libGraphite/quickdraw/ppat.hpp"
#include "libGraphite/quickdraw/rle.hpp"

@implementation QuickDraw

+ (NSData *)tiffFromPict:(NSData *)data {
    std::vector<char> buffer((char *)data.bytes, (char *)data.bytes+data.length);
    graphite::data::data gData(std::make_shared<std::vector<char>>(buffer), data.length);
    try {
        auto surface = graphite::qd::pict(std::make_shared<graphite::data::data>(gData), 0, "").image_surface().lock();
        if (!surface) return nil;
        // Most software seems to ignore PICT alpha - we will too, as it can contain garbage data
        return [QuickDraw tiffFromRaw:surface->raw() size:surface->size() alpha:false];
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
        auto surface = graphite::qd::cicn(std::make_shared<graphite::data::data>(gData), 0, "").surface().lock();
        return [QuickDraw tiffFromRaw:surface->raw() size:surface->size() alpha:true];
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
        auto surface = graphite::qd::ppat(std::make_shared<graphite::data::data>(gData), 0, "").surface().lock();
        return [QuickDraw tiffFromRaw:surface->raw() size:surface->size() alpha:false];
    } catch (const std::exception& e) {
        return nil;
    }
}

+ (NSData *)ppatFromRep:(NSBitmapImageRep *)rep {
    graphite::qd::ppat ppat([QuickDraw surfaceFromRep:rep]);
    auto data = ppat.data();
    return [NSData dataWithBytes:data->get()->data()+data->start() length:data->size()];
}

+ (NSData *)tiffFromCrsr:(NSData *)data {
    // Quick hack for parsing crsr resources - data is like a ppat but with a mask
    std::vector<char> buffer((char *)data.bytes, (char *)data.bytes+data.length);
    // Clear the first byte to make graphite think it's a normal ppat
    buffer[0] = 0;
    graphite::data::data gData(std::make_shared<std::vector<char>>(buffer), data.length);
    try {
        auto surface = graphite::qd::ppat(std::make_shared<graphite::data::data>(gData), 0, "").surface().lock();
        auto raw = surface->raw();
        // 16x16 1-bit mask is stored at offset 52
        // Loop over the bytes and bits and clear the alpha component as necessary
        for (int i = 0; i < 32; i++) {
            char byte = buffer[i+52];
            for (int j = 0; j < 8; j++) {
                if (!((byte >> (7-j)) & 0x1)) {
                    raw[i*8+j] = 0;
                }
            }
        }
        return [QuickDraw tiffFromRaw:raw size:surface->size() alpha:true];
    } catch (const std::exception& e) {
        return nil;
    }
}


+ (NSData *)tiffFromRle:(NSData *)data {
    std::vector<char> buffer((char *)data.bytes, (char *)data.bytes+data.length);
    graphite::data::data gData(std::make_shared<std::vector<char>>(buffer), data.length);
    try {
        auto surface = graphite::qd::rle(std::make_shared<graphite::data::data>(gData), 0, "").surface().lock();
        return [QuickDraw tiffFromRaw:surface->raw() size:surface->size() alpha:true];
    } catch (const std::exception& e) {
        return nil;
    }
}


+ (NSData *)tiffFromRaw:(std::vector<uint32_t>)raw size:(graphite::qd::size)size alpha:(bool)alpha {
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
    rep.alpha = alpha;
    return rep.TIFFRepresentation;
}

+ (std::shared_ptr<graphite::qd::surface>)surfaceFromRep:(NSBitmapImageRep *)rep {
    int length = (int)(rep.pixelsWide * rep.pixelsHigh) * 4;
    std::vector<graphite::qd::color> buffer((graphite::qd::color *)rep.bitmapData, (graphite::qd::color *)(rep.bitmapData + length));
    graphite::qd::surface surface((int)rep.pixelsWide, (int)rep.pixelsHigh, buffer);
    return std::make_shared<graphite::qd::surface>(surface);
}

@end
