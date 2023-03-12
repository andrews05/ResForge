// The Sound Editor uses the low-level AudioToolbox rather than the newer
// AVFoundation, as an AudioQueueRef can directly play back the formats we need
// while an AVAudioPlayerNode can only play back the "standard" (Float32) format
import AudioToolbox
import RFSupport

extension Notification.Name {
    static let SoundDidStartPlaying = Notification.Name("didStartPlaying")
    static let SoundDidStopPlaying = Notification.Name("didStopPlaying")
}

class SoundResource {
    private(set) var valid = false
    private(set) var playing = false
    private var streamDesc: AudioStreamBasicDescription!
    private var queueRef: AudioQueueRef?
    private var bufferRef: AudioQueueBufferRef?
    private var numPackets: UInt32 = 0

    static var formatNames = [
        k8BitOffsetBinaryFormat: "8-bit Linear PCM",
        k16BitBigEndianFormat: "16-bit Linear PCM",
        kAudioFormatAppleIMA4: "IMA 4:1",
        kAudioFormatALaw: "A-Law 2:1",
        kAudioFormatULaw: "µ-Law 2:1",
        kAudioFormatMACE3: "MACE 3:1",
        kAudioFormatMACE6: "MACE 6:1"
    ]

    init(_ data: Data) {
        self.load(data: data)
    }

    deinit {
        if bufferRef != nil {
            AudioQueueFreeBuffer(queueRef!, bufferRef!)
        }
        if queueRef != nil {
            AudioQueueDispose(queueRef!, true)
        }
    }

    private func getStreamDescription(format: UInt32, channels: UInt32, sampleRate: Double) -> AudioStreamBasicDescription {
        var streamDesc = AudioStreamBasicDescription()
        streamDesc.mSampleRate = sampleRate
        streamDesc.mChannelsPerFrame = channels
        streamDesc.mFormatID = format
        streamDesc.mFormatFlags = 0
        if format == k8BitOffsetBinaryFormat || format == k16BitBigEndianFormat {
            streamDesc.mFormatID = kAudioFormatLinearPCM
            if format == k8BitOffsetBinaryFormat {
                streamDesc.mBitsPerChannel = 8
            } else {
                streamDesc.mBitsPerChannel = 16
                streamDesc.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsBigEndian
            }
            streamDesc.mBytesPerFrame = (streamDesc.mBitsPerChannel/8) * streamDesc.mChannelsPerFrame
            streamDesc.mFramesPerPacket = 1
            streamDesc.mBytesPerPacket = streamDesc.mBytesPerFrame * streamDesc.mFramesPerPacket
        } else {
            var propSize = UInt32(MemoryLayout.size(ofValue: streamDesc))
            AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, nil, &propSize, &streamDesc)
        }
        return streamDesc
    }

    private func initAudioQueue(_ byteSize: UInt32) throws {
        var err: OSStatus
        if bufferRef != nil {
            AudioQueueFreeBuffer(queueRef!, bufferRef!)
            bufferRef = nil
        }
        if queueRef != nil {
            AudioQueueDispose(queueRef!, true)
            queueRef = nil
        }
        err = AudioQueueNewOutput(&streamDesc, {_, _, _ in }, nil, nil, nil, 0, &queueRef)
        try err.throwError()
        err = AudioQueueAllocateBuffer(queueRef!, byteSize, &bufferRef)
        try err.throwError()
        err = AudioQueueAddPropertyListener(queueRef!, kAudioQueueProperty_IsRunning, { inUserData, inAQ, _ in
            var isRunning: UInt32 = 0
            var propSize = UInt32(MemoryLayout.size(ofValue: isRunning))
            let err = AudioQueueGetProperty(inAQ, kAudioQueueProperty_IsRunning, &isRunning, &propSize)
            if err == noErr {
                let sr = Unmanaged<SoundResource>.fromOpaque(inUserData!).takeUnretainedValue()
                sr.playing = isRunning != 0
                NotificationCenter.default.post(name: sr.playing ? .SoundDidStartPlaying : .SoundDidStopPlaying, object: sr)
            }
        }, Unmanaged.passUnretained(self).toOpaque())
        try err.throwError()
    }

    private func parse(_ data: Data) throws -> Bool {
        // Read sound headers
        let reader = BinaryDataReader(data, bigEndian: true)
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
        } else if header.encode == extSH {
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
        } else if header.encode == cmpSH {
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
            // MACE is not supported but this at least allows to see the format id in the info
            if cmpHeader.compressionID == threeToOne {
                format = kAudioFormatMACE3
            } else if cmpHeader.compressionID == sixToOne {
                format = kAudioFormatMACE6
            } else {
                format = cmpHeader.format
            }
            numChannels = header.length
            numPackets = cmpHeader.numFrames
        } else {
            return false
        }

        // Construct stream description
        streamDesc = getStreamDescription(format: format, channels: numChannels, sampleRate: FixedToDouble(header.sampleRate))
        if streamDesc.mBytesPerPacket == 0 {
            return false
        }

        // Setup audio queue
        var byteSize = numPackets * streamDesc.mBytesPerPacket
        let bytesRemaining = UInt32(data.count - reader.position)
        if byteSize > bytesRemaining {
            byteSize = bytesRemaining
        }
        try initAudioQueue(byteSize)
        let buff = bufferRef!.pointee.mAudioData.assumingMemoryBound(to: UInt8.self)
        data.copyBytes(to: buff, from: reader.position..<(reader.position+Int(byteSize)))
        bufferRef!.pointee.mAudioDataByteSize = byteSize
        return true
    }

    func load(data: Data) {
        self.stop()
        do {
            valid = try parse(data)
        } catch {
            valid = false
            streamDesc = nil
        }
    }

    func load(url: URL, format: UInt32, channels: UInt32, sampleRate: Double) throws {
        var err: OSStatus
        var fRef: ExtAudioFileRef?
        var propSize: UInt32
        var fileFrames: Int64 = 0
        var inStreamDesc = AudioStreamBasicDescription()

        self.stop()

        // Open file and get info
        err = ExtAudioFileOpenURL(url as CFURL, &fRef)
        try err.throwError()
        propSize = UInt32(MemoryLayout.size(ofValue: fileFrames))
        err = ExtAudioFileGetProperty(fRef!, kExtAudioFileProperty_FileLengthFrames, &propSize, &fileFrames)
        try err.throwError()
        propSize = UInt32(MemoryLayout.size(ofValue: inStreamDesc))
        err = ExtAudioFileGetProperty(fRef!, kExtAudioFileProperty_FileDataFormat, &propSize, &inStreamDesc)
        try err.throwError()

        // Configure output info and audio buffer
        streamDesc = getStreamDescription(format: format, channels: (channels == 0 ? inStreamDesc.mChannelsPerFrame : channels), sampleRate: (sampleRate == 0 ? inStreamDesc.mSampleRate : sampleRate))
        // Calculate frame count
        let numFrames = (Double(fileFrames) / inStreamDesc.mSampleRate) * streamDesc.mSampleRate
        // Packets = frames / framesPerPacket, but we need to round up
        numPackets = (UInt32(numFrames) + streamDesc.mFramesPerPacket - 1) / streamDesc.mFramesPerPacket
        let byteSize = numPackets * streamDesc.mBytesPerPacket
        try initAudioQueue(byteSize)
        var bufferList = AudioBufferList(
            mNumberBuffers: 1,
            mBuffers: AudioBuffer(
                mNumberChannels: streamDesc.mChannelsPerFrame,
                mDataByteSize: byteSize,
                mData: bufferRef!.pointee.mAudioData
            )
        )

        if format == k16BitBigEndianFormat {
            // If importing to a PCM format the ExtAudioFile can perform any necessary conversion
            err = ExtAudioFileSetProperty(fRef!, kExtAudioFileProperty_ClientDataFormat, propSize, &streamDesc)
            try err.throwError()
            err = ExtAudioFileRead(fRef!, &numPackets, &bufferList)
            try err.throwError()
        } else {
            // Otherwise we need to setup an AudioConverter
            // The ExtAudioFile will convert to an intermediary PCM format which the AudioConverter will convert to our output format
            var tempStreamDesc = getStreamDescription(format: k16BitBigEndianFormat, channels: streamDesc.mChannelsPerFrame, sampleRate: streamDesc.mSampleRate)
            err = ExtAudioFileSetProperty(fRef!, kExtAudioFileProperty_ClientDataFormat, propSize, &tempStreamDesc)
            try err.throwError()
            var converter: AudioConverterRef?
            var uData = (fRef!, tempStreamDesc.mBytesPerPacket)
            err = AudioConverterNew(&tempStreamDesc, &streamDesc, &converter)
            try err.throwError()
            err = AudioConverterFillComplexBuffer(converter!, { _, ioNumberDataPackets, ioData, _, inUserData in
                let uData = inUserData!.load(as: (ExtAudioFileRef, UInt32).self)
                ioData.pointee.mBuffers.mDataByteSize = uData.1 * ioNumberDataPackets.pointee
                ioData.pointee.mBuffers.mData = UnsafeMutableRawPointer.allocate(byteCount: Int(ioData.pointee.mBuffers.mDataByteSize), alignment: 1)
                return ExtAudioFileRead(uData.0, ioNumberDataPackets, ioData)
            }, &uData, &numPackets, &bufferList, nil)
            AudioConverterDispose(converter!)
            try err.throwError()
        }
        ExtAudioFileDispose(fRef!)
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
        guard let queueRef = queueRef else {
            return
        }
        AudioQueueReset(queueRef)
        AudioQueueEnqueueBuffer(queueRef, bufferRef!, 0, nil)
        AudioQueueStart(queueRef, nil)
        AudioQueueStop(queueRef, false)
    }

    func stop() {
        guard let queueRef = queueRef else {
            return
        }
        AudioQueueStop(queueRef, true)
    }

    func export(to url: URL) throws {
        guard let bufferRef = bufferRef else {
            return
        }
        var err: OSStatus
        var fRef: AudioFileID?
        var bytes = bufferRef.pointee.mAudioDataByteSize
        let formatID = (streamDesc.mFormatFlags & kAudioFormatFlagIsBigEndian) != 0 ? kAudioFileAIFFType : kAudioFileAIFCType
        err = AudioFileCreateWithURL(url as CFURL, formatID, &streamDesc, [.eraseFile, .dontPageAlignAudioData], &fRef)
        try err.throwError()
        err = AudioFileWriteBytes(fRef!, false, 0, &bytes, bufferRef.pointee.mAudioData)
        AudioFileClose(fRef!)
        try err.throwError()
    }

    var format: AudioFormatID {
        if streamDesc == nil {
            return 0
        } else if streamDesc.mFormatFlags & kAudioFormatFlagIsBigEndian != 0 {
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
        AudioFormatGetProperty(kAudioFormatProperty_FormatName, specifierSize, &streamDesc, &propertySize, &formatString)
        return formatString?.takeRetainedValue() as String? ?? "unknown"
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
