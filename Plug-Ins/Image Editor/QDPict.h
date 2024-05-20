#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface QDPict : NSObject

+ (NSBitmapImageRep * _Nullable)repFromData:(NSData *)data format:(uint32_t *)format error:(NSError **)outError;
+ (NSData *)dataFromRep:(NSBitmapImageRep *)data;

@end

NS_ASSUME_NONNULL_END
