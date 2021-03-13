//
//  SampleBufferDecoder.swift
//  RearviewKit
//
//  Created by Yuji Nakayama on 2021/03/06.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import Foundation
import VideoToolbox
import CoreImage

class SampleBufferDecoder {
    private var session: VTDecompressionSession?

    func decode(_ sampleBuffer: CMSampleBuffer, completion: @escaping (CIImage?) -> Void) {
        if session == nil {
            VTDecompressionSessionCreate(
                allocator: nil,
                formatDescription: sampleBuffer.formatDescription!,
                decoderSpecification: nil,
                imageBufferAttributes: [kCVPixelBufferPixelFormatTypeKey : kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] as CFDictionary,
                outputCallback: nil,
                decompressionSessionOut: &session
            )
        }

        guard let session = session else { abort() }

        VTDecompressionSessionDecodeFrame(
            session,
            sampleBuffer: sampleBuffer,
            flags: [._EnableTemporalProcessing],
            infoFlagsOut: nil
        ) { (status, infoFlags, imageBuffer, presentationTimeStamp, presentationDuration) in
            if let imageBuffer = imageBuffer {
                let image = CIImage(cvImageBuffer: imageBuffer)
                completion(image)
            } else {
                completion(nil)
            }
        }
    }

    deinit {
        if let session = session {
            // https://developer.apple.com/forums/thread/85678
            VTDecompressionSessionWaitForAsynchronousFrames(session)
            VTDecompressionSessionInvalidate(session)
        }
    }
}
