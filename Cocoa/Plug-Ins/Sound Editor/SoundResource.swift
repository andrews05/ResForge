import AudioToolbox

class SoundResource {
    var valid = false
    var streamDesc = AudioStreamBasicDescription()
    var queueRef: AudioQueueRef? = nil
    var bufferRef: AudioQueueBufferRef? = nil
    var numPackets: UInt32 = 0
    
    static var supportedFormats = [
        k8BitOffsetBinaryFormat: "8 bit uncompressed",
        k16BitBigEndianFormat: "16 bit uncompressed",
        kAudioFormatAppleIMA4: "IMA 4:1",
        kAudioFormatALaw: "A-Law 2:1",
        kAudioFormatULaw: "µ-Law 2:1"
    ]

    init(resource: ResKnifeResource) {
        do {
            valid = try parse(resource.data!)
        } catch {
            valid = false
        }
    }
    
    init(url: URL, format: UInt32, channels: UInt32, sampleRate: Double) {
        load(url: url, format: format, channels: channels, sampleRate: sampleRate)
    }
    
    func getStreamDescription(format: UInt32, channels: UInt32, sampleRate: Double) -> AudioStreamBasicDescription {
        var streamDesc = AudioStreamBasicDescription()
		streamDesc.mSampleRate = sampleRate
		streamDesc.mChannelsPerFrame = channels
        streamDesc.mFormatID = format
        streamDesc.mFormatFlags = 0
        if format == kAudioFormatAppleIMA4 {
            streamDesc.mBitsPerChannel = 0
            streamDesc.mBytesPerFrame = 0
            streamDesc.mFramesPerPacket = 64
            streamDesc.mBytesPerPacket = 34 * streamDesc.mChannelsPerFrame
        } else {
            if format == k8BitOffsetBinaryFormat {
                streamDesc.mBitsPerChannel = 8
                streamDesc.mFormatID = kAudioFormatLinearPCM
            } else if format == k16BitBigEndianFormat {
                streamDesc.mBitsPerChannel = 16
                streamDesc.mFormatID = kAudioFormatLinearPCM
                streamDesc.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsBigEndian
            } else if format == kAudioFormatALaw || format == kAudioFormatULaw {
                streamDesc.mBitsPerChannel = 8
            } else {
                // Legacy formats such as MACE are unsupported on current macOS
                streamDesc.mBytesPerPacket = 0
                return streamDesc
            }
            streamDesc.mBytesPerFrame = (streamDesc.mBitsPerChannel/8) * streamDesc.mChannelsPerFrame
            streamDesc.mFramesPerPacket = 1
            streamDesc.mBytesPerPacket = streamDesc.mBytesPerFrame * streamDesc.mFramesPerPacket
        }
        return streamDesc
    }

    func parse(_ data: Data) throws -> Bool {
        // Read sound headers
        let reader = BinaryDataReader(BinaryData(data: data, bigEndian: true))
        let soundFormat: Int16 = try reader.read()
        if soundFormat == firstSoundFormat {
            let list = SndListResource(
                format: soundFormat,
                numModifiers: try reader.read(),
                modifierPart: ModRef(
                    modNumber: try reader.read(),
                    modInit: try reader.read()
                ),
                numCommands: try reader.read(),
                commandPart: SndCommand(
                    cmd: try reader.read(),
                    param1: try reader.read(),
                    param2: try reader.read()
                )
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
                refCount: try reader.read(),
                numCommands: try reader.read(),
                commandPart: SndCommand(
                    cmd: try reader.read(),
                    param1: try reader.read(),
                    param2: try reader.read()
                )
            )
            if list.numCommands != 1 ||
                list.commandPart.cmd != dataOffsetFlag+bufferCmd {
                return false
            }
        } else {
            return false
        }
        
        let header = SoundHeader(
            samplePtr: try reader.read(),
            length: try reader.read(),
            sampleRate: try reader.read(),
            loopStart: try reader.read(),
            loopEnd: try reader.read(),
            encode: try reader.read(),
            baseFrequency: try reader.read()
        )
        
        let format: UInt32
        let numChannels: UInt32
        if header.encode == stdSH {
            format = k8BitOffsetBinaryFormat
            numChannels = 1
            numPackets = header.length
        } else if (header.encode == extSH) {
            let extHeader = ExtSoundHeader(
                numFrames: try reader.read(),
                AIFFSampleRate: extended80(
                    exp: try reader.read(),
                    man: try reader.read()
                ),
                markerChunk: try reader.read(),
                instrumentChunks: try reader.read(),
                AESRecording: try reader.read(),
                sampleSize: try reader.read(),
                futureUse1: try reader.read(),
                futureUse2: try reader.read(),
                futureUse3: try reader.read(),
                futureUse4: try reader.read()
            )
            format = extHeader.sampleSize == 8 ? k8BitOffsetBinaryFormat : k16BitBigEndianFormat
            numChannels = header.length
            numPackets = extHeader.numFrames
        } else if (header.encode == cmpSH) {
            let cmpHeader = CmpSoundHeader(
                numFrames: try reader.read(),
                AIFFSampleRate: extended80(
                    exp: try reader.read(),
                    man: try reader.read()
                ),
                markerChunk: try reader.read(),
                format: try reader.read(),
                futureUse2: try reader.read(),
                stateVars: try reader.read(),
                leftOverSamples: try reader.read(),
                compressionID: try reader.read(),
                packetSize: try reader.read(),
                snthID: try reader.read(),
                sampleSize: try reader.read()
            )
            format = cmpHeader.format
            numChannels = header.length
            numPackets = cmpHeader.numFrames
        } else {
            return false;
        }
        
        // Construct stream description
        streamDesc = getStreamDescription(format:format, channels:numChannels, sampleRate:FixedToDouble(header.sampleRate));
        if (streamDesc.mBytesPerPacket == 0) {
            return false
        }
        
        // Setup audio queue
        var byteSize = numPackets * streamDesc.mBytesPerPacket
        let bytesRemaining = UInt32(data.count - reader.readIndex)
        if byteSize < bytesRemaining {
            byteSize = bytesRemaining
        }
        var err: OSStatus
        err = AudioQueueNewOutput(&streamDesc, {_,_,_ in }, nil, nil, nil, 0, &queueRef)
        err = AudioQueueAllocateBuffer(queueRef!, byteSize, &bufferRef)
        let buff = bufferRef!.pointee.mAudioData.assumingMemoryBound(to: UInt8.self)
        data.copyBytes(to: buff, from: reader.readIndex..<(reader.readIndex+Int(byteSize)))
        bufferRef!.pointee.mAudioDataByteSize = byteSize
        return true
    }
    
    func load(url: URL, format: UInt32, channels: UInt32, sampleRate: Double) {
        var err: OSStatus
        var fRef: ExtAudioFileRef?
        var propSize: UInt32
        var fileFrames: Int64 = 0
        var inStreamDesc = AudioStreamBasicDescription()
        
        // Open file and get info
        err = ExtAudioFileOpenURL(url as CFURL, &fRef)
        propSize = UInt32(MemoryLayout.size(ofValue: fileFrames))
        err = ExtAudioFileGetProperty(fRef!, kExtAudioFileProperty_FileLengthFrames, &propSize, &fileFrames)
        propSize = UInt32(MemoryLayout.size(ofValue: inStreamDesc))
        err = ExtAudioFileGetProperty(fRef!, kExtAudioFileProperty_FileDataFormat, &propSize, &inStreamDesc)
        
        // Configure output info and audio buffer
        streamDesc = getStreamDescription(format: format, channels: (channels == 0 ? inStreamDesc.mChannelsPerFrame : channels), sampleRate: (sampleRate == 0 ? inStreamDesc.mSampleRate : sampleRate))
        // Packets = frames / framesPerPacket, but we need to round up
        // WARN: This doesn't account for change in sample rate
        numPackets = (UInt32(fileFrames) + streamDesc.mFramesPerPacket - 1) / streamDesc.mFramesPerPacket
        let byteSize = numPackets * streamDesc.mBytesPerPacket
        err = AudioQueueNewOutput(&streamDesc, {_,_,_ in }, nil, nil, nil, 0, &queueRef)
        err = AudioQueueAllocateBuffer(queueRef!, byteSize, &bufferRef)
        var bufferList = AudioBufferList(
            mNumberBuffers: 1,
            mBuffers: AudioBuffer(
                mNumberChannels: streamDesc.mChannelsPerFrame,
                mDataByteSize: byteSize,
                mData: bufferRef!.pointee.mAudioData
            )
        )
        
        if format == k16BitBigEndianFormat  {
            // If importing to a PCM format the ExtAudioFile can perform any necessary conversion
            err = ExtAudioFileSetProperty(fRef!, kExtAudioFileProperty_ClientDataFormat, propSize, &streamDesc)
            err = ExtAudioFileRead(fRef!, &numPackets, &bufferList)
        } else {
            // Otherwise we need to setup an AudioConverter
            // The ExtAudioFile will convert to an intermediary PCM format which the AudioConverter will convert to our output format
            var tempStreamDesc = getStreamDescription(format: k16BitBigEndianFormat, channels: streamDesc.mChannelsPerFrame, sampleRate: streamDesc.mSampleRate)
            err = ExtAudioFileSetProperty(fRef!, kExtAudioFileProperty_ClientDataFormat, propSize, &tempStreamDesc)
            var converter: AudioConverterRef?
            var uData = (fRef!, tempStreamDesc.mBytesPerPacket)
            err = AudioConverterNew(&tempStreamDesc, &streamDesc, &converter)
            err = AudioConverterFillComplexBuffer(converter!, { _, ioNumberDataPackets, ioData, _, inUserData in
                let uData = inUserData!.load(as: (ExtAudioFileRef, UInt32).self)
                ioData.pointee.mBuffers.mDataByteSize = uData.1 * ioNumberDataPackets.pointee
                ioData.pointee.mBuffers.mData = UnsafeMutableRawPointer.allocate(byteCount: Int(ioData.pointee.mBuffers.mDataByteSize), alignment: 1)
                return ExtAudioFileRead(uData.0, ioNumberDataPackets, ioData)
            }, &uData, &numPackets, &bufferList, nil)
        }
        bufferRef!.pointee.mAudioDataByteSize = bufferList.mBuffers.mDataByteSize
        self.valid = true
    }
    
    func data() throws -> Data {
        let byteSize = Int(bufferRef!.pointee.mAudioDataByteSize)
        let capacity = MemoryLayout<SndListResource>.stride +
            MemoryLayout<SoundHeader>.stride +
            MemoryLayout<ExtSoundHeader>.stride +
            byteSize
        let writer = BinaryDataWriter(capacity: capacity)
        
        let list = SndListResource(
            format: firstSoundFormat,
            numModifiers: 1,
            modifierPart: ModRef(
                modNumber: sampledSynth,
                modInit: initStereo // unused
            ),
            numCommands: 1,
            commandPart: SndCommand(
                cmd: dataOffsetFlag+bufferCmd,
                param1: 0, // ignored
                param2: 20 // offset to sound header
            )
        )
        try writer.writeStruct(list)
        
        var header = SoundHeader(
            samplePtr: 0, // 0 = after header
            length: numPackets,
            sampleRate: DoubleToFixed(streamDesc.mSampleRate),
            loopStart: 0,
            loopEnd: 0,
            encode: stdSH,
            baseFrequency: kMiddleC
        )
        if streamDesc.mFormatID == kAudioFormatLinearPCM && streamDesc.mBitsPerChannel == 8 && streamDesc.mChannelsPerFrame == 1 {
            try writer.writeStruct(header)
        } else if streamDesc.mFormatID == kAudioFormatLinearPCM {
            header.encode = extSH
            header.length = streamDesc.mChannelsPerFrame
            try writer.writeStruct(header)
            let extHeader = ExtSoundHeader(
                numFrames: numPackets,
                AIFFSampleRate: extended80(exp: 0, man: 0), // unused
                markerChunk: 0,
                instrumentChunks: 0,
                AESRecording: 0,
                sampleSize: UInt16(streamDesc.mBitsPerChannel),
                futureUse1: 0,
                futureUse2: 0,
                futureUse3: 0,
                futureUse4: 0
            )
            try writer.writeStruct(extHeader)
        } else {
            header.encode = cmpSH
            header.length = streamDesc.mChannelsPerFrame
            try writer.writeStruct(header)
            let cmpHeader = CmpSoundHeader(
                numFrames: numPackets,
                AIFFSampleRate: extended80(exp: 0, man: 0), // unused
                markerChunk: 0,
                format: streamDesc.mFormatID,
                futureUse2: 0,
                stateVars: 0,
                leftOverSamples: 0,
                compressionID: fixedCompression,
                packetSize: 0, // 0 = auto
                snthID: 0,
                sampleSize: UInt16(streamDesc.mBitsPerChannel)
            )
            try writer.writeStruct(cmpHeader)
        }
        
        let buff = bufferRef!.pointee.mAudioData.assumingMemoryBound(to: UInt8.self)
        writer.data.append(UnsafeBufferPointer(start: buff, count: byteSize))
        return writer.data
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

    
    var format: AudioFormatID {
        if streamDesc.mFormatFlags & kAudioFormatFlagIsBigEndian != 0 {
            return k16BitBigEndianFormat
        } else if streamDesc.mFormatID == kAudioFormatLinearPCM {
            return k8BitOffsetBinaryFormat
        } else {
            return streamDesc.mFormatID
        }
    }

    var formatString: String {
        var formatString: Unmanaged<CFString>?
        let specifierSize = UInt32(MemoryLayout.size(ofValue: streamDesc))
        var propertySize = UInt32(MemoryLayout.size(ofValue: formatString))
        let err = AudioFormatGetProperty(kAudioFormatProperty_FormatName, specifierSize, &streamDesc, &propertySize, &formatString)
        return formatString!.takeRetainedValue() as String
    }

    var channels: UInt32 {
        return streamDesc.mChannelsPerFrame
    }

    var sampleRate: Double {
        return streamDesc.mSampleRate
    }
    
    var duration: Double {
        if numPackets == 0 {
            return 0
        }
        return Double(numPackets * streamDesc.mFramesPerPacket) / streamDesc.mSampleRate
    }
}
