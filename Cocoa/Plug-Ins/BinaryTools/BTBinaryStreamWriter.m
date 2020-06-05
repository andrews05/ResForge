#import "BTBinaryStreamWriter.h"
#import "BTBinaryToolsErrors.h"

NSString* BTBinaryStreamErrorDomain = @"BTBinaryStreamErrorDomain";

@interface BTBinaryStreamWriter ()
{
    NSOutputStream* mOutputStream;
    NSError* mError;
    
    uint16_t (*convert_uint16_t)(uint16_t);
    uint32_t (*convert_uint32_t)(uint32_t);
    uint64_t (*convert_uint64_t)(uint64_t);
}

@property (nonatomic, retain, getter = lastError) NSError* error;

@end

@implementation BTBinaryStreamWriter

@synthesize outputStream = mOutputStream;
@synthesize error = mError;

#pragma mark - Lifecycle

-(id)initWithStream:(NSOutputStream *)outputStream andDesiredByteOrder:(CFByteOrder)desiredByteOrder
{
    switch (desiredByteOrder)
    {
        case CFByteOrderBigEndian:
            convert_uint16_t = &CFSwapInt16HostToBig;
            convert_uint32_t = &CFSwapInt32HostToBig;
            convert_uint64_t = &CFSwapInt64HostToBig;
            break;
        case CFByteOrderLittleEndian:
            convert_uint16_t = &CFSwapInt16HostToLittle;
            convert_uint32_t = &CFSwapInt32HostToLittle;
            convert_uint64_t = &CFSwapInt64HostToLittle;
            break;
        default:
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"Got invalid byte order: %ld", desiredByteOrder] userInfo:nil];
            break;
    }
    
    if (!(self = [super init]))
    {
        return nil;
    }
    
    mOutputStream = outputStream;
    
    return self;
}

#pragma mark - Write methods

#define convert_uint8_t(arg) arg

#define CHECK_NUMBER_OF_WRITTEN_BYTES(written, expected) do { \
    if (written == -1) { \
        self.error = [NSError errorWithDomain:BTBinaryStreamErrorDomain code:BTBinaryStreamOperationError userInfo:nil]; \
    } else if (written == 0) { \
        self.error = [NSError errorWithDomain:BTBinaryStreamErrorDomain code:BTBinaryStreamWriterEndOfStream userInfo:nil]; \
    } else if (written < expected) { \
        self.error = [NSError errorWithDomain:BTBinaryStreamErrorDomain code:BTBinaryStreamWriterNotAllBytesWritten userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Expected to write %lu bytes, wrote %ld bytes.", (unsigned long)expected, (long)written]}]; \
    } \
} while (0)

#define WRITE_VALUE(value, type) do { \
    self.error = nil; \
    type* binaryValue = (type*)&value; \
    type convertedValue = convert_##type(*binaryValue); \
    size_t valueSize = sizeof(type); \
    NSInteger written = [mOutputStream write:(const uint8_t*)&convertedValue maxLength:valueSize]; \
    CHECK_NUMBER_OF_WRITTEN_BYTES(written, valueSize); \
} while (0)

#define GENERATE_METHOD(method_name_type, method_signature_type, internal_type) \
-(void)write##method_name_type:(method_signature_type)value { \
    WRITE_VALUE(value, internal_type); \
}

GENERATE_METHOD(Int8, int8_t, uint8_t)
GENERATE_METHOD(UInt8, uint8_t, uint8_t)
GENERATE_METHOD(Int16, int16_t, uint16_t)
GENERATE_METHOD(UInt16, uint16_t, uint16_t)
GENERATE_METHOD(Int32, int32_t, uint32_t)
GENERATE_METHOD(UInt32, uint32_t, uint32_t)
GENERATE_METHOD(Int64, int64_t, uint64_t)
GENERATE_METHOD(UInt64, uint64_t, uint64_t)
GENERATE_METHOD(Float, float, uint32_t)
GENERATE_METHOD(Double, double, uint64_t)


-(void)writeData:(NSData *)data
{
    self.error = nil;
    NSUInteger bytesToWrite = [data length];
    NSInteger written = [mOutputStream write:[data bytes] maxLength:bytesToWrite];
    CHECK_NUMBER_OF_WRITTEN_BYTES(written, (unsigned long)bytesToWrite);
}

-(void)writeString:(NSString*)string withEncoding:(NSStringEncoding)encoding
{
    NSData* dataToWrite = [string dataUsingEncoding:encoding];
    if (dataToWrite == nil)
    {
        self.error = [NSError errorWithDomain:BTBinaryStreamErrorDomain
                                         code:BTBinaryStreamWriterStringEncodingError
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Error in encoding string with encoding: %lu", (unsigned long)encoding]}];
    }
    else
    {
        [self writeData:dataToWrite];
    }
}

@end

