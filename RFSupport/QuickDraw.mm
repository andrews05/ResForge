#import "QuickDraw.h"
#include "libGraphite/quickdraw/pict.hpp"
#include "libGraphite/quickdraw/cicn.hpp"
#include "libGraphite/quickdraw/ppat.hpp"
#include "libGraphite/quickdraw/rle.hpp"

@implementation QuickDraw

+ (NSBitmapImageRep *)repFromPict:(NSData *)data format:(uint32_t *)format error:(NSError **)outError {
    std::vector<char> buffer((char *)data.bytes, (char *)data.bytes+data.length);
    graphite::data::data gData(std::make_shared<std::vector<char>>(buffer), data.length);
    try {
        auto pict = graphite::qd::pict(std::make_shared<graphite::data::data>(gData), 0, "");
        *format = pict.format();
        auto surface = pict.image_surface().lock();
        return [QuickDraw repFromRaw:surface->raw() size:surface->size()];
    } catch (const std::exception& e) {
        NSString *message = [NSString stringWithUTF8String:e.what()];
        *outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadUnknownError userInfo:@{NSLocalizedDescriptionKey:message}];
        return nil;
    }
}

+ (NSData *)pictFromRep:(NSBitmapImageRep *)rep {
    graphite::qd::pict pict([QuickDraw surfaceFromRep:rep]);
    auto data = pict.data();
    return [NSData dataWithBytes:data->get()->data()+data->start() length:data->size()];
}

+ (NSBitmapImageRep *)repFromCicn:(NSData *)data {
    std::vector<char> buffer((char *)data.bytes, (char *)data.bytes+data.length);
    graphite::data::data gData(std::make_shared<std::vector<char>>(buffer), data.length);
    try {
        auto surface = graphite::qd::cicn(std::make_shared<graphite::data::data>(gData), 0, "").surface().lock();
        return [QuickDraw repFromRaw:surface->raw() size:surface->size()];
    } catch (const std::exception& e) {
        return nil;
    }
}

+ (NSData *)cicnFromRep:(NSBitmapImageRep *)rep {
    graphite::qd::cicn cicn([QuickDraw surfaceFromRep:rep]);
    auto data = cicn.data();
    return [NSData dataWithBytes:data->get()->data()+data->start() length:data->size()];
}

+ (NSBitmapImageRep *)repFromPpat:(NSData *)data {
    std::vector<char> buffer((char *)data.bytes, (char *)data.bytes+data.length);
    graphite::data::data gData(std::make_shared<std::vector<char>>(buffer), data.length);
    try {
        auto surface = graphite::qd::ppat(std::make_shared<graphite::data::data>(gData), 0, "").surface().lock();
        return [QuickDraw repFromRaw:surface->raw() size:surface->size()];
    } catch (const std::exception& e) {
        return nil;
    }
}

+ (NSData *)ppatFromRep:(NSBitmapImageRep *)rep {
    graphite::qd::ppat ppat([QuickDraw surfaceFromRep:rep]);
    auto data = ppat.data();
    return [NSData dataWithBytes:data->get()->data()+data->start() length:data->size()];
}

+ (NSBitmapImageRep *)repFromCrsr:(NSData *)data {
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
        return [QuickDraw repFromRaw:raw size:surface->size()];
    } catch (const std::exception& e) {
        return nil;
    }
}


+ (NSBitmapImageRep *)repFromRaw:(std::vector<uint32_t>)raw size:(graphite::qd::size)size {
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nil
                                                                    pixelsWide:size.width()
                                                                    pixelsHigh:size.height()
                                                                 bitsPerSample:8
                                                               samplesPerPixel:4
                                                                      hasAlpha:YES
                                                                      isPlanar:NO
                                                                colorSpaceName:NSDeviceRGBColorSpace
                                                                   bytesPerRow:size.width()*4
                                                                  bitsPerPixel:32];
    memcpy(rep.bitmapData, raw.data(), rep.bytesPerPlane);
    return rep;
}

+ (std::shared_ptr<graphite::qd::surface>)surfaceFromRep:(NSBitmapImageRep *)rep {
    // Ensure 32-bit RGBA
    if (rep.bitsPerPixel != 32 || rep.colorSpace.colorSpaceModel != NSColorSpaceModelRGB) {
        NSBitmapImageRep *newRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nil
                                                                           pixelsWide:rep.pixelsWide
                                                                           pixelsHigh:rep.pixelsHigh
                                                                        bitsPerSample:8
                                                                      samplesPerPixel:4
                                                                             hasAlpha:YES
                                                                             isPlanar:NO
                                                                       colorSpaceName:NSDeviceRGBColorSpace
                                                                          bytesPerRow:rep.pixelsWide*4
                                                                         bitsPerPixel:32];
        [NSGraphicsContext saveGraphicsState];
        NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithBitmapImageRep:newRep];
        [rep draw];
        [NSGraphicsContext restoreGraphicsState];
        rep = newRep;
    }
    int length = (int)(rep.pixelsWide * rep.pixelsHigh) * 4;
    std::vector<graphite::qd::color> buffer((graphite::qd::color *)rep.bitmapData, (graphite::qd::color *)(rep.bitmapData + length));
    graphite::qd::surface surface((int)rep.pixelsWide, (int)rep.pixelsHigh, buffer);
    return std::make_shared<graphite::qd::surface>(surface);
}

@end
