//
//  SIFTOctave.swift
//  SkySight
//
//  Created by Luke Van In on 2022/12/20.
//

import Foundation
import Metal
import MetalPerformanceShaders


final class SIFTOctave {
    
    let size: IntegralSize
    
    let keypoints: SIFTKeypoints
    
    init(
        device: MTLDevice,
        size: IntegralSize,
        keypoints: SIFTKeypoints
    ) {
        self.size = size
        self.keypoints = keypoints
    }
    
    func encode(
        commandBuffer: MTLCommandBuffer,
        texture: MTLTexture
    ) {
        keypoints.encode(
            commandBuffer: commandBuffer,
            inputTexture: texture
        )
    }
}
