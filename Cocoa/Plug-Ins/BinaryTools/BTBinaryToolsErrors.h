extern NSString* BTBinaryStreamErrorDomain;

typedef enum {
    // General errors:
    // ---------------
    
    // This indicates that the read or write operations failed. For more information, inspect the underlying stream's error and status.
    BTBinaryStreamOperationError = 1,
    
    
    // Read errors:
    // ------------
    
    // This indicates that string decoding failed for the specified encoding.
    BTBinaryStreamReaderStringDecodingError = 100,
    
    // This indicates that some bytes were read, but not enough to satisfy the read operation's requirement.
    BTBinaryStreamReaderNotEnoughBytesRead,
    
    // This indicates that no bytes were read, probably because the stream has reached its end.
    BTBinaryStreamReaderEndOfStream,
    
    
    // Write errors:
    // -------------
    
    // This indicates that the given string could not be encoded with the given encoding.
    BTBinaryStreamWriterStringEncodingError = 200,
    
    
    /*
     While these errors exist, testing has shown that NSOutputStream does not behave as documented.
     Overflowing a fixed-capacity stream always returns -1, which will result in a BTBinaryStreamOperationError.
     */
     
    // This indicates that some bytes were written, but not enough to satisfy the operation's requirement.
    BTBinaryStreamWriterNotAllBytesWritten,
    
    // This indicates that no bytes were written, probably because the stream has reached its end.
    BTBinaryStreamWriterEndOfStream
} BTBinaryStreamHandlingErrorCode;
