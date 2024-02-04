#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface QuickDraw : NSObject

+ (NSBitmapImageRep * _Nullable)repFromPict:(NSData *)data format:(uint32_t *)format error:(NSError **)outError;
+ (NSData *)pictFromRep:(NSBitmapImageRep *)data;

@end

NS_ASSUME_NONNULL_END
