//
//  SIFTInterpolateKernel.swift
//  SkySight
//
//  Created by Luke Van In on 2022/12/25.
//

import Foundation
import MetalPerformanceShaders

final class SIFTInterpolateKernel {

    struct Parameters {
        var dogThreshold: Float32
        var maxIterations: Int32
        var maxOffset: Float32
        var width: Int32
        var height: Int32
        var octaveDelta: Float
        var edgeThreshold: Float
        var numberOfScales: Int32
    }
    
    struct InputKeypoint {
        // Coordinate of the keypoint relative to the scaled image.
        let x: Int32
        let y: Int32
        // Index of the scale image in the octave (relative to number of scales
        // per octave).
        let scale: Int32
        let value: Float32
    }
    
    struct OutputKeypoint {
        // True if keypoint is valid, or false if keypoint was rejected.
        var converged: Int32
        // Index of the image in the octave.
        var scale: Int32
        // Relative offset of the sub-scale.
        var subScale: Float32
        // Coordinate relative to the difference-of-gaussians image size.
        var relativeX: Int32
        var relativeY: Int32
        // Coordinate relative to the original image.
        var absoluteX: Float32
        var absoluteY: Float32
        // Pixel color (intensity)
        var value: Float32
        
        var alphaX: Float32
        var alphaY: Float32
        var alphaZ: Float32
    }
    
    private let maximumKeypoints = 4096
    
    private let computePipelineState: MTLComputePipelineState
    private let differenceTextureArray: MTLTexture

    init(device: MTLDevice, textureSize: IntegralSize, numberOfTextures: Int) {
        let library = device.makeDefaultLibrary()!
        
        let function = library.makeFunction(name: "siftInterpolate")!
        
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type2DArray
        descriptor.pixelFormat = .r32Float
        descriptor.width = textureSize.width
        descriptor.height = textureSize.height
        descriptor.arrayLength = numberOfTextures
        descriptor.storageMode = .shared
        descriptor.usage = [.shaderRead, .shaderWrite]
        
        self.computePipelineState = try! device.makeComputePipelineState(
            function: function
        )
        self.differenceTextureArray = device.makeTexture(descriptor: descriptor)!
    }
    
    func encode(
        commandBuffer: MTLCommandBuffer,
        parameters: Buffer<Parameters>,
        differenceTextures: [MTLTexture],
        inputKeypoints: Buffer<InputKeypoint>,
        outputKeypoints: Buffer<OutputKeypoint>
    ) {
        precondition(inputKeypoints.count == outputKeypoints.count)
        precondition(differenceTextureArray.arrayLength == differenceTextures.count)
        
        // TODO: Pass type2DArray into this function instead
        let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
        for i in 0 ..< differenceTextures.count {
            precondition(differenceTextureArray.pixelFormat == differenceTextures[i].pixelFormat)
            precondition(differenceTextureArray.width == differenceTextures[i].width)
            precondition(differenceTextureArray.height == differenceTextures[i].height)
            blitEncoder.copy(
                from: differenceTextures[i],
                sourceSlice: 0,
                sourceLevel: 0,
                to: differenceTextureArray,
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
        encoder.setTexture(differenceTextureArray, index: 0)

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

