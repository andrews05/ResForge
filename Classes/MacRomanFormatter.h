#import <Foundation/Foundation.h>

@interface MacRomanFormatter : NSFormatter
@property UInt32 stringLength;
@property BOOL valueRequired;
@property BOOL exactLengthRequired;

@end
