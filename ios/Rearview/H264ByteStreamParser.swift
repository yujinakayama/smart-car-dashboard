//
//  H264ByteStreamParser.swift
//  H264Player
//
//  Created by Yuji Nakayama on 2019/07/18.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import Foundation
import VideoToolbox
import AVFoundation

protocol H264ByteStreamParserDelegate: NSObjectProtocol {
    func parser(_ parser: H264ByteStreamParser, didBuildSampleBuffer sampleBuffer: CMSampleBuffer)
}

class H264ByteStreamParser {
    typealias CMBlockBufferWithSize = (buffer: CMBlockBuffer, size: Int)

    weak var delegate: H264ByteStreamParserDelegate?

    var unprocessedData = Data()

    var sequenceParameterSetNALUnit: NALUnit?
    var pictureParameterSetNALUnit: NALUnit?
    var cachedFormatDescription: CMFormatDescription?

    func parse(_ paritalStreamData: Data) {
        unprocessedData += paritalStreamData
        parseUnprocessedData()
    }

    private func parseUnprocessedData() {
        while let result = NALUnit.consume(data: unprocessedData) {
            unprocessedData = result.unconsumedData
            process(result.nalUnit)
        }
    }

    private func process(_ nalUnit: NALUnit) {
        switch nalUnit.type {
        case .sequenceParameterSet:
            sequenceParameterSetNALUnit = nalUnit
            cachedFormatDescription = nil
        case .pictureParameterSet:
            pictureParameterSetNALUnit = nalUnit
            cachedFormatDescription = nil
        case .codedSliceOfIDRPicture, .codedSliceOfNonIDRPicture:
            if let sampleBuffer = makeSampleBuffer(from: nalUnit) {
                delegate?.parser(self, didBuildSampleBuffer: sampleBuffer)
            }
        default:
            break
        }
    }

    private func makeVideoFormatDescriptionIfPossible() -> CMFormatDescription? {
        guard let spsNALUnit = sequenceParameterSetNALUnit else { return nil }
        guard let ppsNALUnit = pictureParameterSetNALUnit else { return nil }

        if let formatDescription = cachedFormatDescription {
            return formatDescription
        }

        return spsNALUnit.data.withUnsafeBytes { (spsPointer) in
            ppsNALUnit.data.withUnsafeBytes({ (ppsPointer) in
                cachedFormatDescription = makeVideoFormatDescription(spsPointer: spsPointer, ppsPointer: ppsPointer)
                return cachedFormatDescription
            })
        }
    }

    private func makeVideoFormatDescription(spsPointer: UnsafeRawBufferPointer, ppsPointer: UnsafeRawBufferPointer) -> CMFormatDescription? {
        let parameterSets = [
            spsPointer.baseAddress!.bindMemory(to: UInt8.self, capacity: spsPointer.count),
            ppsPointer.baseAddress!.bindMemory(to: UInt8.self, capacity: spsPointer.count)
        ]

        let parameterSetSizes = [spsPointer.count, ppsPointer.count]

        var formatDescription: CMFormatDescription?

        let status = CMVideoFormatDescriptionCreateFromH264ParameterSets(
            allocator: nil,
            parameterSetCount: parameterSets.count,
            parameterSetPointers: UnsafePointer(parameterSets),
            parameterSetSizes: parameterSetSizes,
            nalUnitHeaderLength: Int32(MemoryLayout<UInt32>.size),
            formatDescriptionOut: &formatDescription
        )

        if status != noErr {
            // TODO: Throw error
            print("\(#function) error: \(status)")
        }

        return formatDescription
    }

    private func makeSampleBuffer(from nalUnit: NALUnit) -> CMSampleBuffer? {
        guard let formatDescription = makeVideoFormatDescriptionIfPossible() else { return nil }
        guard let block = makeBlockBuffer(from: nalUnit) else { return nil }

        let sampleSizeArray = UnsafePointer<Int>([block.size])

        var sampleBuffer: CMSampleBuffer?

        let status = CMSampleBufferCreate(
            allocator: nil,
            dataBuffer: block.buffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDescription,
            sampleCount: 1,
            sampleTimingEntryCount: 0,
            sampleTimingArray: nil,
            sampleSizeEntryCount: 1,
            sampleSizeArray: sampleSizeArray,
            sampleBufferOut: &sampleBuffer
        )

        if status != noErr {
            // TODO: Throw error
            print("\(#function) error: \(status)")
        }

        configureAttachments(of: sampleBuffer!)

        return sampleBuffer
    }

    private func configureAttachments(of sampleBuffer: CMSampleBuffer) {
        let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true)!
        let attachment = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFMutableDictionary.self)
        let key = Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque()
        let value = Unmanaged.passUnretained(kCFBooleanTrue).toOpaque()
        CFDictionarySetValue(attachment, key, value)
    }

    private func makeBlockBuffer(from nalUnit: NALUnit) -> CMBlockBufferWithSize? {
        guard let headerBlock = makeHeaderBlockBuffer(from: nalUnit) else { return nil }
        guard let dataBlock = makeDataBlockBuffer(from: nalUnit) else { return nil }

        let blockBuffer = headerBlock.buffer

        let status = CMBlockBufferAppendBufferReference(
            blockBuffer,
            targetBBuf: dataBlock.buffer,
            offsetToData: 0,
            dataLength: dataBlock.size,
            flags: 0
        )

        if status != noErr {
            // TODO: Throw error
            print("\(#function) error: \(status)")
        }

        return (blockBuffer, headerBlock.size + dataBlock.size)
    }

    private func makeHeaderBlockBuffer(from nalUnit: NALUnit) -> CMBlockBufferWithSize? {
        let blockPointer = UnsafeMutablePointer<UInt32>.allocate(capacity: 1)
        blockPointer.initialize(to: CFSwapInt32HostToBig(UInt32(nalUnit.data.count)))

        let blockLength = MemoryLayout<UInt32>.size

        var blockBuffer: CMBlockBuffer?

        let status = CMBlockBufferCreateWithMemoryBlock(
            allocator: nil,
            memoryBlock: UnsafeMutableRawPointer(blockPointer),
            blockLength: blockLength,
            blockAllocator: nil,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: blockLength,
            flags: 0,
            blockBufferOut: &blockBuffer
        )

        if status != noErr {
            // TODO: Throw error
            print("\(#function) error: \(status)")
        }

        return (blockBuffer!, blockLength)
    }

    private func makeDataBlockBuffer(from nalUnit: NALUnit) -> CMBlockBufferWithSize? {
        let blockPointer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: nalUnit.data.count)
        _ = blockPointer.initialize(from: nalUnit.data)

        let blockLength = blockPointer.count

        var blockBuffer: CMBlockBuffer?

        let status = CMBlockBufferCreateWithMemoryBlock(
            allocator: nil,
            memoryBlock: UnsafeMutableRawPointer(blockPointer.baseAddress!),
            blockLength: blockLength,
            blockAllocator: nil,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: blockLength,
            flags: 0,
            blockBufferOut: &blockBuffer
        )

        if status != noErr {
            // TODO: Throw error
            print("\(#function) error: \(status)")
        }

        return (blockBuffer!, blockLength)
    }
}

extension H264ByteStreamParser {
    // https://www.google.com/search?q=%22Direct+Access+to+Video+Encoding+and+Decoding%22+PDF
    // https://stackoverflow.com/a/29525001
    struct NALUnit {
        // https://yumichan.net/video-processing/video-compression/introduction-to-h264-nal-unit/
        // 5 bits; max 31.
        enum UnitType: UInt8 {
            case unspecified0 = 0
            case codedSliceOfNonIDRPicture
            case codedSliceDataPartitionA
            case codedSliceDataPartitionB
            case codedSliceDataPartitionC
            case codedSliceOfIDRPicture
            case supplementalEnhancementInformation
            case sequenceParameterSet
            case pictureParameterSet
            case accessUnitDelimiter
            case endOfSequence // 10
            case endOfStream
            case fillerData
            case sequenceParameterSetExtension
            case prefixNALUnit
            case subsetSequenceParameterSet
            case reserved16
            case reserved17
            case reserved18
            case codedSliceOfAuxiliaryCodedPictureWithoutPartitioning
            case codedSliceExtension // 20
            case codedSliceExtensionForDepthViewComponents
            case reserved22
            case reserved23
            case unspecified24
            case unspecified25
            case unspecified26
            case unspecified27
            case unspecified28
            case unspecified29
            case unspecified30
            case unspecified31
        }

        // TODO: Support 3 bytes code ([0x00, 0x00, 0x01])
        static let startCode = Data([0x00, 0x00, 0x00, 0x01])

        static func consume(data: Data) -> (nalUnit: NALUnit, unconsumedData: Data)? {
            guard let firstStartCodeRange = data.range(of: NALUnit.startCode) else { return nil }

            guard let secondStartCodeRange = data.range(of: NALUnit.startCode, options: [], in: firstStartCodeRange.upperBound..<data.count) else { return nil }

            let nalUnit = NALUnit(data: data.subdata(in: firstStartCodeRange.upperBound..<secondStartCodeRange.lowerBound))
            let unconsumedData = data.subdata(in: secondStartCodeRange.lowerBound..<data.count)

            return (nalUnit, unconsumedData)
        }

        // Not including start code
        let data: Data

        var header: UInt8 {
            return data[0]
        }

        var type: UnitType {
            let typeValue = header & 0b11111
            return UnitType(rawValue: typeValue)!
        }
    }
}
