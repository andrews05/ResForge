#import <Foundation/Foundation.h>

@interface NSData (RKHexRepresentationExtensions)
- (NSString *)hexRepresentation;
- (NSString *)asciiRepresentation;
- (NSString *)nonLossyAsciiRepresentation;
@end

@interface NSString (RKHexConversionExtensions)
- (NSData *)dataFromHex;
@end