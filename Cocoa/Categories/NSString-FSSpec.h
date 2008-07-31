#import <Foundation/Foundation.h>

@interface NSString (ResKnifeFSSpecExtensions)

- (FSRef *)createFSRef;
- (FSSpec *)createFSSpec;

@end


@interface NSString (ResKnifeBooleanExtensions)

- (BOOL)boolValue;
+ (NSString *)stringWithBool:(BOOL)boolean;

@end