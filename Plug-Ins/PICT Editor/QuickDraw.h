#import <Foundation/Foundation.h>
#import "ResKnifeResourceProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface QuickDraw : NSObject

+ (NSData *)tiffFromPict:(NSData *)data;
+ (NSData *)pictFromRep:(NSBitmapImageRep *)data;
+ (NSData *)tiffFromCicn:(NSData *)data;
+ (NSData *)cicnFromRep:(NSBitmapImageRep *)data;
+ (NSData *)tiffFromPpat:(NSData *)data;
+ (NSData *)ppatFromRep:(NSBitmapImageRep *)data;

@end

NS_ASSUME_NONNULL_END
