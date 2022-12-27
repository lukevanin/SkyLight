//
//  SIFT.swift
//  SkySight
//
//  Created by Luke Van In on 2022/12/18.
//

import Foundation
import OSLog
import Metal
import MetalPerformanceShaders


private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier!,
    category: "SIFT"
)


struct SIFTKeypoint {
    var x: Float
    var y: Float
    var sigma: Float
}


final class SIFTOctave {
    
    let scale: DifferenceOfGaussians.Octave
    
    let keypointTextures: [MTLTexture]
    let images: [Image<Float>]
    
    private let extremaFunction: SIFTExtremaFunction
    
    init(
        device: MTLDevice,
        scale: DifferenceOfGaussians.Octave,
        extremaFunction: SIFTExtremaFunction
    ) {
        
        let textureDescriptor: MTLTextureDescriptor = {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .r32Float,
                width: scale.size.width,
                height: scale.size.height,
                mipmapped: false
            )
            descriptor.usage = [.shaderRead, .shaderWrite]
            descriptor.storageMode = .shared
            return descriptor
        }()
        
        let keypointTextures = {
            var textures = [MTLTexture]()
            for _ in 0 ..< scale.numberOfScales {
                let texture = device.makeTexture(
                    descriptor: textureDescriptor
                )!
                textures.append(texture)
            }
            return textures
        }()
        
        self.scale = scale
        self.extremaFunction = extremaFunction
        self.keypointTextures = keypointTextures
        self.images = {
            var images = [Image<Float>]()
            for texture in keypointTextures {
                let image = Image<Float>(texture: texture, defaultValue: 0)
                images.append(image)
            }
            return images
        }()
    }
    
    func encode(commandBuffer: MTLCommandBuffer) {
        for i in 0 ..< keypointTextures.count {
            extremaFunction.encode(
                commandBuffer: commandBuffer,
                inputTexture0: scale.differenceTextures[i + 0],
                inputTexture1: scale.differenceTextures[i + 1],
                inputTexture2: scale.differenceTextures[i + 2],
                outputTexture: keypointTextures[i]
            )
        }
    }
    
    func getKeypoints() -> [SIFTKeypoint] {
        updateImagesFromTextures()
        return getKeypointsFromImages()
    }
    
    private func updateImagesFromTextures() {
        for image in images {
            image.updateFromTexture()
        }
    }

    private func getKeypointsFromImages() -> [SIFTKeypoint] {
        var keypoints = [SIFTKeypoint]()
        for z in 0 ..< images.count {
            for y in 0 ..< scale.size.height {
                for x in 0 ..< scale.size.width  {
                    if let keypoint = keypointAt(x: x, y: y, z: z) {
                        keypoints.append(keypoint)
                    }
                }
            }
        }
        return keypoints
    }
    
    private func keypointAt(x: Int, y: Int, z: Int) -> SIFTKeypoint? {
        let image = images[z]
        let value = image[x, y]
        precondition(value == 0 || value == 1)

        if value == 0 {
            return nil
        }

        let keypoint = SIFTKeypoint(
            x: Float(x) * scale.delta,
            y: Float(y) * scale.delta,
            sigma: scale.sigmas[z + 1]
        )
        return keypoint
    }
}


/// See: http://www.ipol.im/pub/art/2014/82/article.pdf
/// See: https://medium.com/jun94-devpblog/cv-13-scale-invariant-local-feature-extraction-3-sift-315b5de72d48
final class SIFT {
    
    struct Configuration {
        
        // Dimensions of the input image.
        var inputSize: IntegralSize
        
        // Threshold over the Difference of Gaussians response (value
        // relative to scales per octave = 3)
        var differenceOfGaussiansThreshold: Float = 0.015
        
        // Threshold over the ratio of principal curvatures (edgeness).
        var edgeThreshold: Float = 10.0
    }

    let configuration: Configuration
    let dog: DifferenceOfGaussians
    let octaves: [SIFTOctave]
    
    private let commandQueue: MTLCommandQueue
    
    init(
        device: MTLDevice,
        configuration: Configuration
    ) {
        let dog = DifferenceOfGaussians(
            device: device,
            configuration: DifferenceOfGaussians.Configuration(
                inputDimensions: configuration.inputSize
            )
        )
        let octaves: [SIFTOctave] = {
            let extremaFunction = SIFTExtremaFunction(device: device)
            
            var octaves = [SIFTOctave]()
            for scale in dog.octaves {
                let octave = SIFTOctave(
                    device: device,
                    scale: scale,
                    extremaFunction: extremaFunction
                )
                octaves.append(octave)
            }
            return octaves
        }()
        
        self.commandQueue = device.makeCommandQueue()!
        self.configuration = configuration
        self.dog = dog
        self.octaves = octaves
    }
    
    func getKeypoints(_ inputTexture: MTLTexture) -> [SIFTKeypoint] {
        findKeypoints(inputTexture: inputTexture)
        return getKeypointsFromOctaves()
    }
    
    private func findKeypoints(inputTexture: MTLTexture) {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        
        dog.encode(
            commandBuffer: commandBuffer,
            originalTexture: inputTexture
        )
        
        for octave in octaves {
            octave.encode(
                commandBuffer: commandBuffer
            )
        }
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        let elapsedTime = commandBuffer.gpuEndTime - commandBuffer.gpuStartTime
        print("Command buffer", String(format: "%0.3f", elapsedTime), "seconds")
    }
    
    private func getKeypointsFromOctaves() -> [SIFTKeypoint] {
        var keypoints = [SIFTKeypoint]()
        for octave in octaves {
            keypoints.append(contentsOf: octave.getKeypoints())
        }
        return keypoints
    }

//    private func findKeypoints() {
//        let startTime = CFAbsoluteTimeGetCurrent()
//        var keypoints = [Keypoint]()
//        for octave in octaves {
//            keypoints.append(contentsOf: octave.findKeypoints())
//        }
//        self.keypoints = keypoints
//        let endTime = CFAbsoluteTimeGetCurrent()
//        let elapsedTime = endTime - startTime
//        print("Find keypoints", String(format: "%0.3f", elapsedTime), "seconds")
//        print("Found", keypoints.count, "keypoints")
//    }

}
