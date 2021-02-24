#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface QuickDraw : NSObject

+ (NSBitmapImageRep * _Nullable)repFromPict:(NSData *)data;
+ (NSData *)pictFromRep:(NSBitmapImageRep *)data;
+ (NSBitmapImageRep * _Nullable)repFromCicn:(NSData *)data;
+ (NSData *)cicnFromRep:(NSBitmapImageRep *)data;
+ (NSBitmapImageRep * _Nullable)repFromPpat:(NSData *)data;
+ (NSData *)ppatFromRep:(NSBitmapImageRep *)data;
+ (NSBitmapImageRep * _Nullable)repFromCrsr:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
