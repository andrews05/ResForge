#import <Foundation/Foundation.h>

@interface ResourceStream : NSObject
{
	char *data;
}

@property UInt32 length;
@property UInt32 bytesToGo;

+ (instancetype)streamWithData:(NSData *)data;

- (instancetype)initStreamWithBytes:(char *)d length:(UInt32)l;

- (char *)data;

- (UInt32)bytesToNull;
- (void)advanceAmount:(UInt32)l pad:(BOOL)pad;					// advance r/w pointer and optionally write padding bytes
- (void)peekAmount:(UInt32)l toBuffer:(void *)buffer;				// read bytes without advancing pointer
- (void)readAmount:(UInt32)l toBuffer:(void *)buffer;				// stream reading
- (void)writeAmount:(UInt32)l fromBuffer:(const void *)buffer;	// stream writing

@end
