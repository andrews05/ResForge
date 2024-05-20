#import "QDPict.h"
#include "libGraphite/quickdraw/pict.hpp"

@implementation QDPict

+ (NSBitmapImageRep *)repFromData:(NSData *)data format:(uint32_t *)format error:(NSError **)outError {
    std::vector<char> buffer((char *)data.bytes, (char *)data.bytes+data.length);
    graphite::data::data gData(std::make_shared<std::vector<char>>(buffer), data.length);
    try {
        auto pict = graphite::qd::pict(std::make_shared<graphite::data::data>(gData), 0, "");
        *format = pict.format();
        auto surface = pict.image_surface().lock();
        return [self repFromRaw:surface->raw() size:surface->size()];
    } catch (const std::exception& e) {
        NSString *message = [NSString stringWithUTF8String:e.what()];
        *outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadUnknownError userInfo:@{NSLocalizedDescriptionKey:message}];
        return nil;
    }
}

+ (NSData *)dataFromRep:(NSBitmapImageRep *)rep {
    graphite::qd::pict pict([self surfaceFromRep:rep]);
    auto data = pict.data();
    return [NSData dataWithBytes:data->get()->data()+data->start() length:data->size()];
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
