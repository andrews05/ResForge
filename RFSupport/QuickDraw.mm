#import "QuickDraw.h"
#include "libGraphite/quickdraw/format/pict.hpp"
#include "libGraphite/quickdraw/format/cicn.hpp"
#include "libGraphite/quickdraw/format/ppat.hpp"
#include "libGraphite/spriteworld/rleX.hpp"

@implementation QuickDraw

+ (NSBitmapImageRep *)repFromPict:(NSData *)data format:(uint32_t *)format error:(NSError **)outError {
    graphite::data::block gData(data.bytes, data.length, false);
    try {
        auto pict = graphite::quickdraw::pict(gData);
//        *format = pict.format();
        auto surface = pict.surface();
        return [QuickDraw repFromRaw:surface.raw() size:surface.size()];
    } catch (const std::exception& e) {
        NSString *message = [NSString stringWithUTF8String:e.what()];
        *outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadUnknownError userInfo:@{NSLocalizedDescriptionKey:message}];
        return nil;
    }
}

+ (NSData *)pictFromRep:(NSBitmapImageRep *)rep {
    auto surface = [QuickDraw surfaceFromRep:rep];
    graphite::quickdraw::pict pict(surface);
    auto data = pict.data();
    return [NSData dataWithBytes:data.get<void *>() length:data.size()];
}

+ (NSBitmapImageRep *)repFromCicn:(NSData *)data {
    graphite::data::block gData(data.bytes, data.length, false);
    try {
        auto surface = graphite::quickdraw::cicn(gData).surface();
        return [QuickDraw repFromRaw:surface.raw() size:surface.size()];
    } catch (const std::exception& e) {
        return nil;
    }
}

+ (NSData *)cicnFromRep:(NSBitmapImageRep *)rep {
    auto surface = [QuickDraw surfaceFromRep:rep];
    graphite::quickdraw::cicn cicn(surface);
    auto data = cicn.data();
    return [NSData dataWithBytes:data.get<void *>() length:data.size()];
}

+ (NSBitmapImageRep *)repFromPpat:(NSData *)data {
    graphite::data::block gData(data.bytes, data.length, false);
    try {
        auto surface = graphite::quickdraw::ppat(gData).surface();
        return [QuickDraw repFromRaw:surface.raw() size:surface.size()];
    } catch (const std::exception& e) {
        return nil;
    }
}

+ (NSData *)ppatFromRep:(NSBitmapImageRep *)rep {
    auto surface = [QuickDraw surfaceFromRep:rep];
    graphite::quickdraw::ppat ppat(surface);
    auto data = ppat.data();
    return [NSData dataWithBytes:data.get<void *>() length:data.size()];
}

+ (NSBitmapImageRep *)repFromCrsr:(NSData *)data {
    // Quick hack for parsing crsr resources - data is like a ppat but with a mask
    graphite::data::block gData(data.length);
    auto buffer = gData.get<uint8_t *>();
    memcpy(buffer, data.bytes, data.length);
    // Clear the first byte to make graphite think it's a normal ppat
    buffer[0] = 0;
    try {
        auto surface = graphite::quickdraw::ppat(gData).surface();
        // 16x16 1-bit mask is stored at offset 52
        // Loop over the bytes and bits and clear the alpha component as necessary
        for (auto i = 0; i < 32; i++) {
            auto byte = buffer[i+52];
            for (auto j = 0; j < 8; j++) {
                if (!((byte >> (7-j)) & 0x1)) {
                    surface.set(i*8+j, graphite::quickdraw::colors::clear());
                }
            }
        }
        return [QuickDraw repFromRaw:surface.raw() size:surface.size()];
    } catch (const std::exception& e) {
        return nil;
    }
}

+ (NSData *)rlexFromReps:(NSArray<NSBitmapImageRep *> *)reps {
    graphite::spriteworld::rleX rlex(graphite::quickdraw::size<std::int16_t>(reps[0].pixelsWide, reps[0].pixelsHigh), reps.count);
    for (auto i = 0; i < reps.count; i++) {
        auto surface = [QuickDraw surfaceFromRep:reps[i]];
        rlex.write_frame(i, surface);
    }
    auto data = rlex.data();
    return [NSData dataWithBytes:data.get<void *>() length:data.size()];
}

+ (NSArray<NSBitmapImageRep *> *)repsFromRlex:(NSData *)data {
    graphite::data::block gData(data.bytes, data.length, false);
    try {
        auto rlex = graphite::spriteworld::rleX(gData);
        NSMutableArray<NSBitmapImageRep *> *reps = [NSMutableArray arrayWithCapacity:rlex.frame_count()];
        for (auto i=0; i<rlex.frame_count(); i++) {
            auto surface = rlex.frame_surface(i);
            [reps addObject:[QuickDraw repFromRaw:surface.raw() size:surface.size()]];
        }
        return reps;
    } catch (const std::exception& e) {
        return nil;
    }
}


+ (NSBitmapImageRep *)repFromRaw:(graphite::data::block)raw size:(graphite::quickdraw::size<std::int16_t>)size {
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nil
                                                                    pixelsWide:size.width
                                                                    pixelsHigh:size.height
                                                                 bitsPerSample:8
                                                               samplesPerPixel:4
                                                                      hasAlpha:YES
                                                                      isPlanar:NO
                                                                colorSpaceName:NSDeviceRGBColorSpace
                                                                   bytesPerRow:size.width*4
                                                                  bitsPerPixel:32];
    memcpy(rep.bitmapData, raw.get<void *>(), rep.bytesPerPlane);
    return rep;
}

+ (graphite::quickdraw::surface)surfaceFromRep:(NSBitmapImageRep *)rep {
    graphite::quickdraw::surface surface(rep.pixelsWide, rep.pixelsHigh);
    auto raw = surface.raw().get<uint8_t *>();
    // Ensure 32-bit RGBA
    if (rep.bitsPerPixel != 32 || rep.colorSpace.colorSpaceModel != NSColorSpaceModelRGB) {
        NSBitmapImageRep *newRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:&raw
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
    } else {
        memcpy(raw, rep.bitmapData, rep.pixelsWide * rep.pixelsHigh * 4);
    }
    return surface;
}

@end
