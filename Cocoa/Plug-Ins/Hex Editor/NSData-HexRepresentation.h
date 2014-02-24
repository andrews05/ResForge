#import <Foundation/Foundation.h>

@interface NSData (ResKnifeHexRepresentationExtensions)
- (NSString *)hexRepresentation;
- (NSString *)asciiRepresentation;
- (NSString *)nonLossyAsciiRepresentation;
@end

@interface NSString (ResKnifeHexConversionExtensions)
- (NSData *)dataFromHex;
@end
