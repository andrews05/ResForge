#import <Foundation/Foundation.h>

@interface BTBinaryStreamWriter : NSObject

@property (nonatomic, readonly, retain) NSOutputStream* outputStream;

-(id)initWithStream:(NSOutputStream*)outputStream andDesiredByteOrder:(CFByteOrder)desiredByteOrder;

-(void)writeInt8:(int8_t)value;
-(void)writeUInt8:(uint8_t)value;

-(void)writeInt16:(int16_t)value;
-(void)writeUInt16:(uint16_t)value;

-(void)writeInt32:(int32_t)value;
-(void)writeUInt32:(uint32_t)value;

-(void)writeInt64:(int64_t)value;
-(void)writeUInt64:(uint64_t)value;

-(void)writeFloat:(float)value;
-(void)writeDouble:(double)value;

-(void)writeData:(NSData*)data;

/**
 Write a string, encoding it first using a specified encoding.
 
 @warning The endianness of the writer is ignored for strings! This means that it will be determined
 entirely by the encoding. It is recommended you either use an endianness-agnostic encoding (such as UTF8)
 or specify the endianness explictly in the encoding (such as NSUTF16BigEndianStringEncoding).
 */
-(void)writeString:(NSString*)string withEncoding:(NSStringEncoding)encoding;

-(NSError*)lastError;

@end
