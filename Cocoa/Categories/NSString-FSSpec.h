#import <Foundation/Foundation.h>

@interface NSString (NGSFSSpec)

- (FSRef *)createFSRef;
- (FSSpec *)createFSSpec;

@end


@interface NSString (NGSBoolean)

- (BOOL)boolValue;
+ (NSString *)stringWithBool:(BOOL)boolean;

@end