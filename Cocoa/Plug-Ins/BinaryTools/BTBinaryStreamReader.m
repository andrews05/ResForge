#import "BTBinaryStreamReader.h"
#import "BTBinaryToolsErrors.h"

@interface BTBinaryStreamReader ()
{
    NSInputStream* mInputStream;
    NSError* mError;
    
    uint16_t (*convert_uint16_t)(uint16_t);
    uint32_t (*convert_uint32_t)(uint32_t);
    uint64_t (*convert_uint64_t)(uint64_t);
}

@property (nonatomic, retain, getter = lastError) NSError* error;

@end

@implementation BTBinaryStreamReader

@synthesize error = mError;

#pragma mark - Lifecycle

-(id)initWithStream:(NSInputStream *)inputStream andSourceByteOrder:(CFByteOrder)streamByteOrder
{
    switch (streamByteOrder)
    {
        case CFByteOrderLittleEndian:
            convert_uint16_t = &CFSwapInt16LittleToHost;
            convert_uint32_t = &CFSwapInt32LittleToHost;
            convert_uint64_t = &CFSwapInt64LittleToHost;
            break;
        case CFByteOrderBigEndian:
            convert_uint16_t = &CFSwapInt16BigToHost;
            convert_uint32_t = &CFSwapInt32BigToHost;
            convert_uint64_t = &CFSwapInt64BigToHost;
            break;
        default:
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"Got invalid byte order: %ld", streamByteOrder] userInfo:nil];
            break;
    }
    
    if (!(self = [super init]))
    {
        return nil;
    }
    
    mInputStream = inputStream;
    
    return self;
}

-(id)initWithData:(NSData *)data andSourceByteOrder:(CFByteOrder)streamByteOrder
{
    NSInputStream* inputStream = [NSInputStream inputStreamWithData:data];
    if (inputStream == nil)
    {
        return nil;
    }
    
    [inputStream open];
    
    return [self initWithStream:inputStream andSourceByteOrder:streamByteOrder];
}

#pragma mark - Reading methods

#define convert_uint8_t(arg) arg

#define READ_VALUE(return_type, internal_type) do { \
    self.error = nil; \
    internal_type internalValue; \
    size_t valueSize = sizeof(internal_type); \
    NSInteger readResult = [mInputStream read:(uint8_t*)&internalValue maxLength:valueSize]; \
    if (readResult == -1) \
    { \
        self.error = [NSError errorWithDomain:BTBinaryStreamErrorDomain code:BTBinaryStreamOperationError userInfo:nil]; \
    } \
    else if (readResult == 0) \
    { \
        self.error = [NSError errorWithDomain:BTBinaryStreamErrorDomain code:BTBinaryStreamReaderEndOfStream userInfo:@{NSLocalizedDescriptionKey: @"End of stream reached."}]; \
    } \
    else if (readResult > 0 && readResult < valueSize) \
    { \
        self.error = [NSError errorWithDomain:BTBinaryStreamErrorDomain code:BTBinaryStreamReaderNotEnoughBytesRead userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat: @"Needed to read %zu bytes, but read only %lu.", (unsigned long)valueSize, readResult]}]; \
    } \
    \
    internalValue = convert_##internal_type(internalValue); \
    return_type* returnValue = (return_type*)&internalValue; \
    \
    return *returnValue; \
} while (0)

#define GENERATE_METHOD(method_name_type, return_type, internal_type) \
-(return_type)read##method_name_type { \
    READ_VALUE(return_type, internal_type); \
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

-(NSData *)readDataOfLength:(NSUInteger)bytesToRead
{
    self.error = nil;
    NSData* result = nil;
    
    uint8_t* readBuffer = malloc(bytesToRead);
    NSInteger numberOfByteRead = [mInputStream read:readBuffer maxLength:bytesToRead];
    
    if (numberOfByteRead == bytesToRead)
    {
        result = [NSData dataWithBytesNoCopy:readBuffer length:numberOfByteRead freeWhenDone:YES];
    }
    else if (numberOfByteRead > 0)
    {
        result = [NSData dataWithBytes:readBuffer length:numberOfByteRead];
        self.error = [NSError errorWithDomain:BTBinaryStreamErrorDomain code:BTBinaryStreamReaderNotEnoughBytesRead userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat: @"Needed to read %lu bytes, but read only %ld.", (unsigned long)bytesToRead, (long)numberOfByteRead]}];
        free(readBuffer);
    }
    else if (numberOfByteRead == 0)
    {
        result = [NSData data];
        self.error = [NSError errorWithDomain:BTBinaryStreamErrorDomain code:BTBinaryStreamReaderEndOfStream userInfo:@{NSLocalizedDescriptionKey: @"End of stream reached."}];
        free(readBuffer);
    }
    else // numberOfBytesRead == -1
    {
        [NSError errorWithDomain:BTBinaryStreamErrorDomain code:BTBinaryStreamOperationError userInfo:nil];
        free(readBuffer);
    }
    
    return result;
}

-(NSString *)readStringWithEncoding:(NSStringEncoding)stringEncoding andLength:(NSUInteger)bytesToRead
{
    self.error = nil;
    
    NSData* stringBytes = [self readDataOfLength:bytesToRead];
    if ([stringBytes length] != bytesToRead)
    {
        // Error already set by data reading operation, abort.
        return nil;
    }
    
    NSString* result = [[NSString alloc] initWithData:stringBytes encoding:stringEncoding];
    if (result == nil)
    {
        self.error = [NSError errorWithDomain:BTBinaryStreamErrorDomain
                                         code:BTBinaryStreamReaderStringDecodingError
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Error decoding string with encoding: %lu", (unsigned long)stringEncoding]}];
    }
    
    return result;
}

@end
