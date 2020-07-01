#import "ResourceStream.h"

@implementation ResourceStream
@synthesize length;
@synthesize bytesToGo;

+ (instancetype)streamWithData:(NSData *)data
{
    return [[self alloc] initStreamWithBytes:(char *)[data bytes] length:(UInt32)data.length];
}

- (instancetype)initStreamWithBytes:(char *)d length:(UInt32)l
{
	self = [super init];
	if (!self) return nil;
	data = d;
    length = l;
	bytesToGo = l;
	return self;
}

- (char *)data
{
	return data;
}

- (UInt32)bytesToNull
{
	UInt32 dist = 0;
	while (dist < bytesToGo) {
		if (*(char *)(data+dist) == 0x00)
			return dist;
		dist++;
	}
	return bytesToGo;
}

#pragma mark -

- (void)advanceAmount:(UInt32)l
{
    [self advanceAmount:l pad:NO];
}

- (void)advanceAmount:(UInt32)l pad:(BOOL)pad
{
	if (l > bytesToGo) l = bytesToGo;
	if (l > 0) {
		if (pad) memset(data, 0, l);
		data += l;
		bytesToGo -= l;
	}
}

- (void)peekAmount:(UInt32)l toBuffer:(void *)buffer
{
	if (l > bytesToGo) l = bytesToGo;
	if (l > 0) memmove(buffer, data, l);
}

- (void)readAmount:(UInt32)l toBuffer:(void *)buffer
{
    if (l > bytesToGo) {
        // Zero the buffer if we don't have enough data to fill it
        memset(buffer, 0, l);
        l = bytesToGo;
    }
	if (l > 0) {
		memmove(buffer, data, l);
		data += l;
		bytesToGo -= l;
	}
}

- (void)writeAmount:(UInt32)l fromBuffer:(const void *)buffer
{
	if (l > bytesToGo) l = bytesToGo;
	if (l > 0) {
		memmove(data, buffer, l);
		data += l;
		bytesToGo -= l;
	}
}

@end