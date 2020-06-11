import AudioToolbox

class SoundResource {
    var valid = false
    var streamDesc = AudioStreamBasicDescription()
    var queueRef: AudioQueueRef? = nil
    var bufferRef: AudioQueueBufferRef? = nil
    
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
    
    func initxx(url: URL, format: UInt32, channels: UInt32, sampleRate: Double) {
        var err: OSStatus
        var fRef: ExtAudioFileRef? = nil
        var inStreamDesc = AudioStreamBasicDescription()
        var streamDescSize = UInt32(MemoryLayout.size(ofValue: inStreamDesc))
		var fileFrames: Int64 = 0
		var propSize = UInt32(MemoryLayout.size(ofValue: fileFrames))
        err = ExtAudioFileOpenURL(url as CFURL, &fRef)
        err = ExtAudioFileGetProperty(fRef!, kExtAudioFileProperty_FileDataFormat, &streamDescSize, &inStreamDesc)
        err = ExtAudioFileGetProperty(fRef!, kExtAudioFileProperty_FileLengthFrames, &propSize, &fileFrames)
		
		var outStreamDesc = getStreamDescription(format: format, channels: (channels == 0 ? inStreamDesc.mChannelsPerFrame : channels), sampleRate: (sampleRate == 0 ? inStreamDesc.mSampleRate : sampleRate))
		let byteSize = (UInt32(fileFrames) * outStreamDesc.mBytesPerPacket) / outStreamDesc.mFramesPerPacket
        err = AudioQueueNewOutput(&outStreamDesc, {_,_,_ in }, nil, nil, nil, 0, &queueRef)
        err = AudioQueueAllocateBuffer(queueRef!, byteSize, &bufferRef)
        bufferRef!.pointee.mAudioDataByteSize = byteSize
		var bufferList = AudioBufferList(
			mNumberBuffers: 1,
			mBuffers: AudioBuffer(
				mNumberChannels: outStreamDesc.mChannelsPerFrame,
				mDataByteSize: byteSize,
				mData: bufferRef!.pointee.mAudioData
			)
		)
        err = ExtAudioFileSetProperty(fRef!, kExtAudioFileProperty_ClientDataFormat, streamDescSize, &outStreamDesc)
		var framesRead = UInt32(fileFrames)
		err = ExtAudioFileRead(fRef!, &framesRead, &bufferList)
    }
    
    init(url: URL, format: UInt32, channels: UInt32, sampleRate: Double) {
        var err: OSStatus
        var fRef: AudioFileID?
        var inStreamDesc = AudioStreamBasicDescription()
        var streamDescSize = UInt32(MemoryLayout.size(ofValue: inStreamDesc))
        var filePackets: Int64 = 0
        var propSize = UInt32(MemoryLayout.size(ofValue: filePackets))
        err = AudioFileOpenURL(url as CFURL, AudioFilePermissions.readPermission, 0, &fRef)
        err = AudioFileGetProperty(fRef!, kAudioFilePropertyDataFormat, &streamDescSize, &inStreamDesc)
        err = AudioFileGetProperty(fRef!, kAudioFilePropertyAudioDataPacketCount, &propSize, &filePackets)
        
        let fileFrames = UInt32(filePackets) * inStreamDesc.mFramesPerPacket
        var outStreamDesc = getStreamDescription(format: format, channels: (channels == 0 ? inStreamDesc.mChannelsPerFrame : channels), sampleRate: (sampleRate == 0 ? inStreamDesc.mSampleRate : sampleRate))
        let byteSize = (fileFrames * outStreamDesc.mBytesPerPacket) / outStreamDesc.mFramesPerPacket
        err = AudioQueueNewOutput(&outStreamDesc, {_,_,_ in }, nil, nil, nil, 0, &queueRef)
        err = AudioQueueAllocateBuffer(queueRef!, byteSize, &bufferRef)
        bufferRef!.pointee.mAudioDataByteSize = byteSize
        var bufferList = AudioBufferList(
            mNumberBuffers: 1,
            mBuffers: AudioBuffer(
                mNumberChannels: outStreamDesc.mChannelsPerFrame,
                mDataByteSize: byteSize,
                mData: bufferRef!.pointee.mAudioData
            )
        )
        var converter: AudioConverterRef?
        var numPackets = UInt32(filePackets)
        var uData = (fRef!, UnsafeMutablePointer<Int64>.allocate(capacity: 1))
        err = AudioConverterNew(&inStreamDesc, &outStreamDesc, &converter)
        err = AudioConverterFillComplexBuffer(converter!, { inAudioConverter, ioNumberDataPackets, ioData, outDataPacketDescription, inUserData in
            let uData = inUserData!.load(as: (AudioFileID, UnsafeMutablePointer<Int64>).self)
            ioData.pointee.mBuffers.mDataByteSize = 1024
            ioData.pointee.mBuffers.mData = UnsafeMutableRawPointer.allocate(byteCount: 1024, alignment: 1)
            outDataPacketDescription?.pointee = UnsafeMutablePointer<AudioStreamPacketDescription>.allocate(capacity: Int(ioNumberDataPackets.pointee))
            let err = AudioFileReadPacketData(uData.0, false, &ioData.pointee.mBuffers.mDataByteSize, outDataPacketDescription?.pointee, uData.1.pointee, ioNumberDataPackets, ioData.pointee.mBuffers.mData)
            uData.1.pointee += Int64(ioNumberDataPackets.pointee)
            return err
        }, &uData, &numPackets, &bufferList, nil)
        return
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
            streamDesc.mBytesPerPacket = 34
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
        let numFrames: UInt32
        if header.encode == stdSH {
            numChannels = 1
            numFrames = header.length;
            format = k8BitOffsetBinaryFormat
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
            numFrames = extHeader.numFrames
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
            numFrames = cmpHeader.numFrames
        } else {
            return false;
        }
        
        // Construct stream description
        streamDesc = getStreamDescription(format:format, channels:numChannels, sampleRate:FixedToDouble(header.sampleRate));
        if (streamDesc.mBytesPerPacket == 0) {
            return false
        }
        
        // Setup audio queue
        var byteSize = UInt32(data.count - reader.readIndex)
        let expectedSize = numFrames * streamDesc.mBytesPerPacket
        if byteSize > expectedSize {
            byteSize = expectedSize
        }
        var err: OSStatus
        err = AudioQueueNewOutput(&streamDesc, {_,_,_ in }, nil, nil, nil, 0, &queueRef)
        err = AudioQueueAllocateBuffer(queueRef!, byteSize, &bufferRef)
        bufferRef!.pointee.mAudioDataByteSize = byteSize
//        data.withUnsafeBytes({ rawBufferPointer in
//            bufferRef!.pointee.mAudioData.copyMemory(from: rawBufferPointer.baseAddress!+reader.readIndex, byteCount: Int(byteSize))
//        })
        let buff = bufferRef!.pointee.mAudioData.assumingMemoryBound(to: UInt8.self)
        data.copyBytes(to: buff, from: reader.readIndex..<(reader.readIndex+Int(byteSize)))
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

    
    var format: AudioFormatID {
        if streamDesc.mFormatFlags & kAudioFormatFlagIsBigEndian != 0 {
            return k16BitBigEndianFormat
        } else if streamDesc.mFormatID == kAudioFormatLinearPCM {
            return k8BitOffsetBinaryFormat
        } else {
            return streamDesc.mFormatID
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
