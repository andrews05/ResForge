#import <Foundation/Foundation.h>
#import "ResKnifeResourceProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface QuickDraw : NSObject

+ (NSData *)tiffFromPict:(NSData *)pictData;
+ (NSData *)pictFromTiff:(NSData *)tiffData;
+ (NSData *)tiffFromCicn:(NSData *)data;
+ (NSData *)cicnFromTiff:(NSData *)tiffData;

@end

NS_ASSUME_NONNULL_END
