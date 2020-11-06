#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface QuickDraw : NSObject

+ (NSData * _Nullable)tiffFromPict:(NSData *)data;
+ (NSData *)pictFromRep:(NSBitmapImageRep *)data;
+ (NSData * _Nullable)tiffFromCicn:(NSData *)data;
+ (NSData *)cicnFromRep:(NSBitmapImageRep *)data;
+ (NSData * _Nullable)tiffFromPpat:(NSData *)data;
+ (NSData *)ppatFromRep:(NSBitmapImageRep *)data;
+ (NSData * _Nullable)tiffFromCrsr:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
