//
//  SIFTOrientationKernel.swift
//  SkySight
//
//  Created by Luke Van In on 2022/12/25.
//

import Foundation
import MetalPerformanceShaders

final class SIFTOrientationKernel {

//    struct Parameters {
//        let delta: Float32
//        let lambda: Float32
//        let orientationThreshold: Float32
//    }
//
//    struct InputKeypoint {
//        let absoluteX: Int32
//        let absoluteY: Int32
//        let scale: Int32
//        let sigma: Float32
//    }
//
//    struct OutputKeypoint {
//        let count: Int32
//        let orientations: [Float32]
//    }
    
//    typealias Parameters = SIFTOrientationKeypoint
    
    private let maximumKeypoints = 4096
    
    private let computePipelineState: MTLComputePipelineState
    private let gradientTextureArray: MTLTexture

    init(device: MTLDevice, textureSize: IntegralSize, numberOfTextures: Int) {
        let library = device.makeDefaultLibrary()!
        
        let function = library.makeFunction(name: "siftOrientation")!
        
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type2DArray
        descriptor.pixelFormat = .rg32Float
        descriptor.width = textureSize.width
        descriptor.height = textureSize.height
        descriptor.arrayLength = numberOfTextures
        descriptor.storageMode = .shared
        descriptor.usage = [.shaderRead, .shaderWrite]
        
        self.computePipelineState = try! device.makeComputePipelineState(
            function: function
        )
        self.gradientTextureArray = device.makeTexture(descriptor: descriptor)!
    }
    
    func encode(
        commandBuffer: MTLCommandBuffer,
        parameters: Buffer<SIFTOrientationParameters>,
        gradientTextures: [MTLTexture],
        inputKeypoints: Buffer<SIFTOrientationKeypoint>,
        outputKeypoints: Buffer<SIFTOrientationResult>
    ) {
        precondition(inputKeypoints.count == outputKeypoints.count)
        precondition(gradientTextureArray.arrayLength == gradientTextures.count)
        
        // TODO: Pass type2DArray into this function instead
        let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
        for i in 0 ..< gradientTextures.count {
            precondition(gradientTextureArray.pixelFormat == gradientTextures[i].pixelFormat)
            precondition(gradientTextureArray.width == gradientTextures[i].width)
            precondition(gradientTextureArray.height == gradientTextures[i].height)
            blitEncoder.copy(
                from: gradientTextures[i],
                sourceSlice: 0,
                sourceLevel: 0,
                to: gradientTextureArray,
                destinationSlice: i,
                destinationLevel: 0,
                sliceCount: 1,
                levelCount: 1
            )
        }
        blitEncoder.endEncoding()
        
        
        let encoder = commandBuffer.makeComputeCommandEncoder()!
        encoder.setComputePipelineState(computePipelineState)
        encoder.setBuffer(outputKeypoints.data, offset: 0, index: 0)
        encoder.setBuffer(inputKeypoints.data, offset: 0, index: 1)
        encoder.setBuffer(parameters.data, offset: 0, index: 2)
        encoder.setTexture(gradientTextureArray, index: 0)

        // Set the compute kernel's threadgroup size of 16x16 = 256
        // TODO: Get threadgroup size from command buffer.
        let threadgroupSize = MTLSize(
            width: 256, // TODO: min(256, inputKeypoints)
            height: 1,
            depth: 1
        )
        // Calculate the number of rows and columns of threadgroups given the width of the input image
        // Ensure that you cover the entire image (or more) so you process every pixel
        // Since we're only dealing with a 2D data set, set depth to 1
        let threadgroupCount = MTLSize(
            width: (inputKeypoints.count + threadgroupSize.width - 1) / threadgroupSize.width,
            height: 1,
            depth: 1
        )
        encoder.dispatchThreadgroups(
            threadgroupCount,
            threadsPerThreadgroup: threadgroupSize
        )
        encoder.endEncoding()
    }
}

