//
//  VideoFileReader.swift
//  SkySight
//
//  Created by Luke Van In on 2022/12/18.
//

import Foundation
import AVFoundation


final class VideoFileReader {
    
    func readVideoFile(fileURL: URL, sample: (CMSampleBuffer) async -> Void) async {
        let asset = AVURLAsset(url: fileURL)
        let reader = try! AVAssetReader(asset: asset)
        let videoTrack = reader.asset.tracks(withMediaType: .video).first!
        let videoTrackTimeRange = try! await videoTrack.load(.timeRange)
        let videoTrackOutput = AVAssetReaderTrackOutput(
            track: videoTrack,
            outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferMetalCompatibilityKey as String: true,
            ]
        )
        videoTrackOutput.supportsRandomAccess = false
        videoTrackOutput.markConfigurationAsFinal()
        reader.add(videoTrackOutput)

        print(
            "reading time range",
            String(format: "%0.2f", videoTrackTimeRange.start.seconds),
            "-",
            String(format: "%0.2f", videoTrackTimeRange.end.seconds)
        )
        reader.startReading()
        
        var oldTime = CFAbsoluteTimeGetCurrent()
        var count = 0
        while let sampleBuffer = videoTrackOutput.copyNextSampleBuffer() {
            let newTime = CFAbsoluteTimeGetCurrent()
            count += 1
            print(
                "read sample",
                count,
                "at",
                String(format: "%0.2f", sampleBuffer.presentationTimeStamp.seconds),
                "/",
                String(format: "%0.2f", videoTrackTimeRange.end.seconds),
                "@",
                String(format: "%0.3f", newTime - oldTime),
                "seconds"
            )
            await sample(sampleBuffer)
        }
    }
}
