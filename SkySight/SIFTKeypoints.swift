//
//  SIFTExtrema.swift
//  SkySight
//
//  Created by Luke Van In on 2022/12/20.
//

import Foundation
import Metal


final class SIFTKeypoints {
    
//    let size: IntegralSize
//    let numberOfExtremaLayers: Int
//
//    let extremaTextures: [MTLTexture]
//
//    let extremaImages: [Image<Float32>]
//
//    let differenceOfGaussians: DifferenceOfGaussians
//
//    private let extremaFunction: SIFTExtremaFunction

    init(
        device: MTLDevice,
        size: IntegralSize,
        numberOfExtremaLayers: Int,
        differenceOfGaussians: DifferenceOfGaussians
    ) {
        
//        let texture1Descriptor: MTLTextureDescriptor = {
//            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
//                pixelFormat: .r32Float,
//                width: size.width,
//                height: size.height,
//                mipmapped: false
//            )
//            descriptor.usage = [.shaderRead, .shaderWrite]
//            descriptor.storageMode = .shared
//            return descriptor
//        }()
//
////        precondition(numberOfExtremaLayers == differenceOfGaussians.count - 2)
//
//        self.differenceOfGaussians = differenceOfGaussians
//        self.numberOfExtremaLayers = numberOfExtremaLayers
//
//        self.extremaFunction = {
//            let function = SIFTExtremaFunction(device: device)
//            return function
//        }()
//
//        let extremaTextures = {
//            var textures = [MTLTexture]()
//            for _ in 0 ..< numberOfExtremaLayers {
//                let texture = device.makeTexture(
//                    descriptor: texture1Descriptor
//                )!
//                textures.append(texture)
//            }
//            return textures
//        }()
//        self.extremaTextures = extremaTextures
//
//        self.extremaImages = {
//            var images = [Image<Float32>]()
//            for texture in extremaTextures {
//                let image = Image<Float32>(
//                    texture: texture,
//                    defaultValue: .zero
//                )
//                images.append(image)
//            }
//            return images
//        }()
    }
    
    func encode(
        commandBuffer: MTLCommandBuffer,
        inputTexture: MTLTexture
    ) {
        // Extrema (maxima and minima).
//        for i in 0 ..< numberOfExtremaLayers {
//            extremaFunction.encode(
//                commandBuffer: commandBuffer,
//                inputTexture0: differenceOfGaussians.differenceTextures[i + 0],
//                inputTexture1: differenceOfGaussians.differenceTextures[i + 1],
//                inputTexture2: differenceOfGaussians.differenceTextures[i + 2],
//                outputTexture: extremaTextures[i]
//            )
//        }
    }
    
//    func updateBuffers() {
//        for image in extremaImages {
//            image.update()
//        }
//    }

//    func findKeypoints() -> [Keypoint] {
//        var candidates = [Keypoint]()
//        for z in 0 ..< extremaCount {
//            for y in 1 ..< size.height - 1 {
//                for x in 1 ..< size.width - 1 {
//                    if let keypoint = keypointAt(x: x, y: y, z: z) {
//                        candidates.append(keypoint)
//                    }
//                }
//            }
//        }
//        return candidates
//    }
    
//    private func keypointAt(x: Int, y: Int, z: Int) -> Keypoint? {
//        let image = extremaImages[z]
//        let value = image[x, y]
//
//        if value == -1 {
//            return nil
//        }
//
//        let keypoint = Keypoint(
//            octave: octave,
//            layer: z + 1,
//            x: x,
//            y: y
//        )
//        return keypoint
//    }
}
