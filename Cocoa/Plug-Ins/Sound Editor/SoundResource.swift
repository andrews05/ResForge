import AudioToolbox

typealias extended80 = Darwin.Float80
typealias UnsignedFixed = UInt32
let fixed1: UInt32 = 1<<16
func FixedToDouble(_ x: UnsignedFixed) -> Double {
    return Double(x) * 1.0/Double(fixed1)
}

class SoundResource {
    var valid = false
    var streamDesc = AudioStreamBasicDescription()
    var queueRef: AudioQueueRef? = nil
    var bufferRef: AudioQueueBufferRef? = nil
    
    static var supportedFormats = [
        k8BitOffsetBinaryFormat: "8 bit uncompressed",
        k16BitBigEndianFormat: "16 bit uncompressed",
        kIMACompression: "IMA 4:1",
        kALawCompression: "A-Law 2:1",
        kULawCompression: "µ-Law 2:1"
    ]

    init(resource: ResKnifeResource) {
        valid = parse(resource.data!)
    }
    
    init(url: URL, format: Int, channels: UInt, sampleRate: Double) {
        var err: OSStatus
        var fRef: ExtAudioFileRef? = nil
        var streamDescSize = UInt32(MemoryLayout.size(ofValue: streamDesc))
        err = ExtAudioFileOpenURL(url as CFURL, &fRef)
        err = ExtAudioFileGetProperty(fRef!, kExtAudioFileProperty_FileDataFormat, &streamDescSize, &streamDesc)

        _ = setStreamDescription(format: format, channels: channels, sampleRate: sampleRate)
        err = ExtAudioFileSetProperty(fRef!, kExtAudioFileProperty_ClientDataFormat, streamDescSize, &streamDesc)
    }
    
    func setStreamDescription(format: Int, channels: UInt, sampleRate: Double) -> Bool {
        if sampleRate > 0 {
            streamDesc.mSampleRate = sampleRate
        }
        if channels > 0 {
            streamDesc.mChannelsPerFrame = UInt32(channels)
        }
        streamDesc.mFormatID = AudioFormatID(format)
        streamDesc.mFormatFlags = 0
        if format == kIMACompression {
            streamDesc.mBitsPerChannel = 0
            streamDesc.mBytesPerFrame = 0
            streamDesc.mFramesPerPacket = 64
            streamDesc.mBytesPerPacket = 34
        } else {
            if format == k8BitOffsetBinaryFormat {
                streamDesc.mBitsPerChannel = 8
                streamDesc.mFormatID = kAudioFormatLinearPCM
            } else if format == k16BitBigEndianFormat {
                streamDesc.mBitsPerChannel = 16
                streamDesc.mFormatID = kAudioFormatLinearPCM
                streamDesc.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsBigEndian
            } else if format == kALawCompression || format == kULawCompression {
                streamDesc.mBitsPerChannel = 8;
            } else {
                return false;
            }
            streamDesc.mBytesPerFrame = UInt32((streamDesc.mBitsPerChannel/8) * streamDesc.mChannelsPerFrame);
            streamDesc.mFramesPerPacket = 1;
            streamDesc.mBytesPerPacket = streamDesc.mBytesPerFrame * streamDesc.mFramesPerPacket;
        }
        return true
    }

    func parse(_ data: Data) -> Bool {
        // Read sound headers
        let stream = BTBinaryStreamReader(data: data, andSourceByteOrder: CFByteOrder(CFByteOrderBigEndian.rawValue))!
        let soundFormat = stream.readInt16()
        if soundFormat == firstSoundFormat {
            let list = SndListResource(
                format: soundFormat,
                numModifiers: stream.readInt16(),
                modifierPart: ModRef(
                    modNumber: UInt16(stream.readInt16()),
                    modInit: Int(stream.readInt32())
                ),
                numCommands: stream.readInt16(),
                commandPart: SndCommand(
                    cmd: UInt16(bitPattern: stream.readInt16()),
                    param1: stream.readInt16(),
                    param2: Int(stream.readInt32())
                ),
                dataPart: 0
            )
            if list.numModifiers != 1 ||
                list.modifierPart.modNumber != sampledSynth ||
                list.numCommands != 1 ||
                list.commandPart.cmd != dataOffsetFlag+bufferCmd {
                return false
            }
        } else if soundFormat == secondSoundFormat {
            let list = Snd2ListResource(
                format: soundFormat,
                refCount: stream.readInt16(),
                numCommands: stream.readInt16(),
                commandPart: SndCommand(
                    cmd: UInt16(stream.readInt16()),
                    param1: stream.readInt16(),
                    param2: Int(stream.readInt32())
                ),
                dataPart: 0
            )
            if list.numCommands != 1 ||
                list.commandPart.cmd != dataOffsetFlag+bufferCmd {
                return false
            }
        } else {
            return false
        }
        
        let header = SoundHeader(
            samplePtr: UInt(stream.readInt32()),
            length: UInt(stream.readInt32()),
            sampleRate: UnsignedFixed(stream.readInt32()),
            loopStart: UInt(stream.readInt32()),
            loopEnd: UInt(stream.readInt32()),
            encode: UInt8(bitPattern: stream.readInt8()),
            baseFrequency: UInt8(stream.readInt8()),
            sampleArea: 0
        )
        
        let format: Int
        let numChannels: UInt
        let numFrames: UInt
        if header.encode == stdSH {
            numChannels = 1
            numFrames = header.length;
            format = k8BitOffsetBinaryFormat
        } else if (header.encode == extSH) {
            let extHeader = ExtSoundHeader(
                samplePtr: header.samplePtr,
                numChannels: header.length,
                sampleRate: header.sampleRate,
                loopStart: header.loopStart,
                loopEnd: header.loopEnd,
                encode: header.encode,
                baseFrequency: header.baseFrequency,
                numFrames: UInt(stream.readInt32()),
                AIFFSampleRate: extended80(
                    exp: stream.readInt16(),
                    man: (
                        UInt16(stream.readInt16()),
                        UInt16(stream.readInt16()),
                        UInt16(stream.readInt16()),
                        UInt16(stream.readInt16())
                    )
                ),
                markerChunk: UInt(stream.readInt32()),
                instrumentChunks: UInt(stream.readInt32()),
                AESRecording: UInt(stream.readInt32()),
                sampleSize: UInt16(stream.readInt16()),
                futureUse1: UInt16(stream.readInt16()),
                futureUse2: UInt(stream.readInt32()),
                futureUse3: UInt(stream.readInt32()),
                futureUse4: UInt(stream.readInt32()),
                sampleArea: 0
            )
            format = extHeader.sampleSize == 8 ? k8BitOffsetBinaryFormat : k16BitBigEndianFormat
            numChannels = header.length
            numFrames = extHeader.numFrames
        } else if (header.encode == cmpSH) {
            let cmpHeader = CmpSoundHeader(
                samplePtr: header.samplePtr,
                numChannels: header.length,
                sampleRate: header.sampleRate,
                loopStart: header.loopStart,
                loopEnd: header.loopEnd,
                encode: header.encode,
                baseFrequency: header.baseFrequency,
                numFrames: UInt(stream.readInt32()),
                AIFFSampleRate: extended80(
                    exp: stream.readInt16(),
                    man: (
                        UInt16(bitPattern: stream.readInt16()),
                        UInt16(bitPattern: stream.readInt16()),
                        UInt16(bitPattern: stream.readInt16()),
                        UInt16(bitPattern: stream.readInt16())
                    )
                ),
                markerChunk: UInt(stream.readInt32()),
                format: OSType(stream.readInt32()),
                futureUse2: UInt(stream.readInt32()),
                stateVars: UInt(stream.readInt32()),
                leftOverSamples: UInt(stream.readInt32()),
                compressionID: stream.readInt16(),
                packetSize: UInt16(stream.readInt16()),
                snthID: UInt16(stream.readInt16()),
                sampleSize: UInt16(stream.readInt16()),
                sampleArea: 0
            )
            format = Int(cmpHeader.format)
            numChannels = header.length
            numFrames = cmpHeader.numFrames
        } else {
            return false;
        }
        
        // Construct stream description
        let valid = setStreamDescription(format:format, channels:numChannels, sampleRate:FixedToDouble(header.sampleRate));
        if (!valid) {
            return false
        }
        
        // Setup audio queue
        var byteSize = UInt32(UInt(data.count) - stream.bytesRead)
        let expectedSize = UInt32(numFrames * UInt(streamDesc.mBytesPerPacket))
        if byteSize > expectedSize {
            byteSize = expectedSize
        }
        var err: OSStatus
        err = AudioQueueNewOutput(&streamDesc, {_,_,_ in }, nil, nil, nil, 0, &queueRef)
        err = AudioQueueAllocateBuffer(queueRef!, byteSize, &bufferRef)
        bufferRef!.pointee.mAudioDataByteSize = byteSize
//        data.withUnsafeBytes({ rawBufferPointer in
//            bufferRef!.pointee.mAudioData.copyMemory(from: rawBufferPointer.baseAddress!+Int(stream.bytesRead), byteCount: Int(byteSize))
//        })
        let buff = bufferRef!.pointee.mAudioData.assumingMemoryBound(to: UInt8.self)
        data.copyBytes(to: buff, from: Int(stream.bytesRead)..<(Int(stream.bytesRead)+Int(byteSize)))
        return true
    }
    
    func play() {
        if let queueRef = queueRef {
            var err: OSStatus
            err = AudioQueueReset(queueRef)
            err = AudioQueueEnqueueBuffer(queueRef, bufferRef!, 0, nil)
            err = AudioQueueStart(queueRef, nil)
        }
    }
    
    func stop() {
        if let queueRef = queueRef {
            var err: OSStatus
            err = AudioQueueReset(queueRef)
        }
    }
    
    func export(to url: URL) {
        if let bufferRef = bufferRef {
            var err: OSStatus
            var fRef: AudioFileID?
            var bytes = bufferRef.pointee.mAudioDataByteSize
            let formatID = (streamDesc.mFormatFlags & kAudioFormatFlagIsBigEndian) != 0 ? kAudioFileAIFFType : kAudioFileAIFCType
            err = AudioFileCreateWithURL(url as CFURL, formatID, &streamDesc, .eraseFile, &fRef)
            err = AudioFileWriteBytes(fRef!, false, 0, &bytes, bufferRef.pointee.mAudioData)
            err = AudioFileClose(fRef!)
        }
    }

    
    var format: Int {
        if streamDesc.mFormatFlags & kAudioFormatFlagIsBigEndian != 0 {
            return k16BitBigEndianFormat
        } else if streamDesc.mFormatID == kAudioFormatLinearPCM {
            return k8BitOffsetBinaryFormat
        } else {
            return Int(streamDesc.mFormatID)
        }
    }

    var channels: UInt32 {
        return streamDesc.mChannelsPerFrame
    }

    var sampleRate: Double {
        return streamDesc.mSampleRate
    }
    
    var duration: Double {
        if streamDesc.mBytesPerPacket == 0 {
            return 0
        }
        let numFrames = (bufferRef!.pointee.mAudioDataByteSize * streamDesc.mFramesPerPacket) / streamDesc.mBytesPerPacket
        return Double(numFrames) / streamDesc.mSampleRate
    }

}
