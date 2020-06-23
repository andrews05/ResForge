#import <Foundation/Foundation.h>

@interface ForkInfo : NSObject
@property NSString *name;
@property HFSUniStr255 uniName;
@property SInt64 size;
@property UInt64 physicalSize;

+ (NSMutableArray *)forksForFile:(FSRef *)fileRef;

@end
