#import <Foundation/Foundation.h>

@interface NSString (ResKnifeFSSpecExtensions)

- (FSRef *)createFSRef;
- (FSSpec *)createFSSpec;

@end
