import AudioToolbox

extension OSStatus {
    func asString() -> String? {
        let n = UInt32(bitPattern: self.littleEndian)
        guard let n1 = UnicodeScalar((n >> 24) & 255), n1.isASCII else { return nil }
        guard let n2 = UnicodeScalar((n >> 16) & 255), n2.isASCII else { return nil }
        guard let n3 = UnicodeScalar((n >>  8) & 255), n3.isASCII else { return nil }
        guard let n4 = UnicodeScalar( n        & 255), n4.isASCII else { return nil }
        return String(n1) + String(n2) + String(n3) + String(n4)
    }

    func detailedErrorMessage() -> String? {
        switch(self) {
        // Audio errors
        case kAudio_BadFilePathError:      return "Bad File Path Error"
        case kAudio_FileNotFoundError:     return "File Not Found Error"
        case kAudio_FilePermissionError:   return "File Permission Error"
        case kAudio_MemFullError:          return "Mem Full Error"
        case kAudio_ParamError:            return "Param Error"
        case kAudio_TooManyFilesOpenError: return "Too Many Files Open Error"
        case kAudio_UnimplementedError:    return "Unimplemented Error"

        // Audio File errors
        case kAudioFileUnsupportedFileTypeError:
            return "The file type is not supported."
        case kAudioFileUnsupportedDataFormatError:
            return "The data format is not supported by this file type."
        case kAudioFileUnsupportedPropertyError:
            return "The property is not supported."
        case kAudioFileBadPropertySizeError:
            return "The size of the property data was not correct."
        case kAudioFilePermissionsError:
            return "The operation violated the file permissions."
        case kAudioFileNotOptimizedError:
            return "The chunks following the audio data chunk are preventing the extension of the audio data chunk. To write more data, you must optimize the file."
        case kAudioFileInvalidChunkError:
            return "Either the chunk does not exist in the file or it is not supported by the file."
        case kAudioFileDoesNotAllow64BitDataSizeError:
            return "The file offset was too large for the file type."
        case kAudioFileInvalidPacketOffsetError:
            return "A packet offset was past the end of the file, or not at the end of the file when a VBR format was written, or a corrupt packet size was read when the packet table was built."
        case kAudioFileInvalidFileError:
            return "The file is malformed, or otherwise not a valid instance of an audio file of its type."
        case kAudioFileOperationNotSupportedError:
            return "The operation cannot be performed."
        case kAudioFileNotOpenError:
            return "The file is closed."
        case kAudioFileEndOfFileError:
            return "End of file."
        case kAudioFilePositionError:
            return "Invalid file position."
        case kAudioFileFileNotFoundError:
            return "File not found."

        // Extended Audio File errors
        case kExtAudioFileError_InvalidChannelMap:
            return "The number of channels does not match the specified format."
        case kExtAudioFileError_InvalidSeek:
            return "An attempt to write, or an offset, is out of bounds."
        case kExtAudioFileError_AsyncWriteBufferOverflow:
            return "An asynchronous write operation could not be completed in time."

        // Audio Queue errors
        case kAudioQueueErr_InvalidBuffer:
            return "The specified audio queue buffer does not belong to the specified audio queue."
        case kAudioQueueErr_BufferEmpty:
            return "The audio queue buffer is empty."
        case kAudioQueueErr_DisposalPending:
            return "The function cannot act on the audio queue because it is being asynchronously disposed of."
        case kAudioQueueErr_InvalidProperty:
            return "The specified property ID is invalid."
        case kAudioQueueErr_InvalidPropertySize:
            return "The size of the specified property is invalid."
        case kAudioQueueErr_InvalidParameter:
            return "The specified parameter ID is invalid."
        case kAudioQueueErr_CannotStart:
            return "The audio queue has encountered a problem and cannot start."
        case kAudioQueueErr_InvalidDevice:
            return "The specified audio hardware device could not be located."
        case kAudioQueueErr_BufferInQueue:
            return "The audio queue buffer cannot be disposed of when it is enqueued."
        case kAudioQueueErr_InvalidRunState:
            return "The queue is running but the function can only operate on the queue when it is stopped, or vice versa."
        case kAudioQueueErr_InvalidQueueType:
            return "The queue is an input queue but the function can only operate on an output queue, or vice versa."
        case kAudioQueueErr_Permissions:
            return "You do not have the required permissions to call the function."
        case kAudioQueueErr_InvalidPropertyValue:
            return "The property value used is not valid."
        case kAudioQueueErr_PrimeTimedOut:
            return "The audio queue’s audio converter failed to convert the requested number of sample frames."
        case kAudioQueueErr_CodecNotFound:
            return "The requested codec was not found."
        case kAudioQueueErr_InvalidCodecAccess:
            return "The codec could not be accessed."
        case kAudioQueueErr_QueueInvalidated:
            return "The audio server has exited, causing the audio queue to become invalid."
        case kAudioQueueErr_RecordUnderrun:
            return "Data was lost because there was no enqueued buffer to store it in."
        case kAudioQueueErr_EnqueueDuringReset:
            return "The system does not allow you to enqueue buffers."
        case kAudioQueueErr_InvalidOfflineMode:
            return "The operation requires the audio queue to be in offline mode but it isn’t, or vice versa."

        // Audio Converter errors
        case kAudioConverterErr_InvalidOutputSize:
            return "The byte size is not an integer multiple of the frame size."
            
        // Audio Format errors
        case kAudioFormatUnsupportedPropertyError:
            return "The specified property is not supported."
        case kAudioFormatUnsupportedDataFormatError:
            return "The playback data format is unsupported."
        case kAudioFormatUnknownFormatError:
            return "The specified data format is not a known format."

        default: return nil
        }
    }
    
    func throwError() throws {
        if self != noErr {
            let message = self.detailedErrorMessage()
            let info = message == nil ? nil : [NSLocalizedDescriptionKey: message!]
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(self), userInfo: info)
        }
    }
}
