//
//  SIFTDescriptor.swift
//  SkySight
//
//  Created by Luke Van In on 2023/01/02.
//

import Foundation


struct SIFTDescriptor {
 
    // Detected keypoint.
    let keypoint: SIFTKeypoint
    // Principal orientation.
    let theta: Float
    // Raw floating point features
    let rawFeatures: [Float]
    // Quantized features
    let features: [Int]
    
    static func distance(_ a: SIFTDescriptor, _ b: SIFTDescriptor) -> Float {
        precondition(a.features.count == 128)
        precondition(b.features.count == 128)
        var t = 0
        for i in 0 ..< 128 {
            let d = b.features[i] - a.features[i]
            t += (d * d)
        }
        return sqrt(Float(t))
    }

    static func match(
        source: [SIFTDescriptor],
        target: [SIFTDescriptor],
        absoluteThreshold: Float,
        relativeThreshold: Float
    ) -> [SIFTCorrespondence] {
        var output = [SIFTCorrespondence]()
        for s in source {
            let correspondence = match(
                source: s,
                target: target,
                absoluteThreshold: absoluteThreshold,
                relativeThreshold: relativeThreshold
            )
            if let correspondence {
                output.append(correspondence)
            }
        }
        return output
    }
    
    static func match(
        source: SIFTDescriptor,
        target: [SIFTDescriptor],
        absoluteThreshold: Float,
        relativeThreshold: Float
    ) -> SIFTCorrespondence? {
        var bestMatchDistance = Float.greatestFiniteMagnitude
        var secondBestMatchDistance = Float.greatestFiniteMagnitude
        var bestMatch: SIFTDescriptor!

        for t in target {
            let distance = self.distance(source, t)
            
            guard distance < absoluteThreshold else {
                continue
            }
            
            guard distance < bestMatchDistance else {
                continue
            }
            
            bestMatch = t
            secondBestMatchDistance = bestMatchDistance
            bestMatchDistance = distance
        }
        
        guard let bestMatch = bestMatch else {
            return nil
        }
        
        guard bestMatchDistance < (secondBestMatchDistance * relativeThreshold) else {
            return nil
        }
        
        return SIFTCorrespondence(
            source: source,
            target: bestMatch,
            featureDistance: bestMatchDistance
        )
    }
}
