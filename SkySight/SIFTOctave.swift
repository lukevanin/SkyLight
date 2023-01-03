//
//  SIFTOctave.swift
//  SkySight
//
//  Created by Luke Van In on 2023/01/03.
//

import Foundation
import Metal


struct SIFTGradient {
    
    static let zero = SIFTGradient(orientation: 0, magnitude: 0)
    
    let orientation: Float
    let magnitude: Float
}


final class SIFTOctave {
    
    let scale: DifferenceOfGaussians.Octave
    
    let keypointTextures: [MTLTexture]
    let keypointImages: [Image<SIMD2<Float>>]

    let gradientTextures: [MTLTexture]
    let gradientImages: [Image<SIFTGradient>]

    private let extremaFunction: SIFTExtremaFunction
    private let gradientFunction: SIFTGradientKernel

    init(
        device: MTLDevice,
        scale: DifferenceOfGaussians.Octave,
        extremaFunction: SIFTExtremaFunction,
        gradientFunction: SIFTGradientKernel
    ) {
        self.scale = scale
        self.extremaFunction = extremaFunction
        self.gradientFunction = gradientFunction

        let keypointTextures = {
            var textures = [MTLTexture]()
            let textureDescriptor: MTLTextureDescriptor = {
                let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                    pixelFormat: .rg32Float,
                    width: scale.size.width,
                    height: scale.size.height,
                    mipmapped: false
                )
                descriptor.usage = [.shaderRead, .shaderWrite]
                descriptor.storageMode = .shared
                return descriptor
            }()
            for _ in 0 ..< scale.numberOfScales {
                let texture = device.makeTexture(
                    descriptor: textureDescriptor
                )!
                textures.append(texture)
            }
            return textures
        }()
        self.keypointTextures = keypointTextures

        let gradientTextures = {
            var textures = [MTLTexture]()
            let textureDescriptor: MTLTextureDescriptor = {
                let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                    pixelFormat: .rg32Float,
                    width: scale.size.width,
                    height: scale.size.height,
                    mipmapped: false
                )
                descriptor.usage = [.shaderRead, .shaderWrite]
                descriptor.storageMode = .shared
                return descriptor
            }()
            for _ in 0 ..< scale.gaussianTextures.count {
                let texture = device.makeTexture(
                    descriptor: textureDescriptor
                )!
                textures.append(texture)
            }
            return textures
        }()
        self.gradientTextures = gradientTextures

        self.keypointImages = {
            var images = [Image<SIMD2<Float>>]()
            for texture in keypointTextures {
                let image = Image<SIMD2<Float>>(texture: texture, defaultValue: .zero)
                images.append(image)
            }
            return images
        }()
        self.gradientImages = {
            var images = [Image<SIFTGradient>]()
            for texture in gradientTextures {
                let image = Image<SIFTGradient>(texture: texture, defaultValue: .zero)
                images.append(image)
            }
            return images
        }()
    }
    
    func encode(commandBuffer: MTLCommandBuffer) {
        encodeExtrema(commandBuffer: commandBuffer)
        encodeGradients(commandBuffer: commandBuffer)
    }
    
    private func encodeExtrema(commandBuffer: MTLCommandBuffer) {
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
    
    private func encodeGradients(commandBuffer: MTLCommandBuffer) {
        for i in 0 ..< gradientTextures.count {
            gradientFunction.encode(
                commandBuffer: commandBuffer,
                inputTexture: scale.gaussianTextures[i],
                outputTexture: gradientTextures[i]
            )
        }
    }
    
    func updateImagesFromTextures() {
        for image in keypointImages {
            image.updateFromTexture()
        }
        for image in gradientImages {
            image.updateFromTexture()
        }
    }

    func getKeypoints() -> [SIFTKeypoint] {
        return getKeypointsFromImages()
    }

    private func getKeypointsFromImages() -> [SIFTKeypoint] {
        var keypoints = [SIFTKeypoint]()
        for s in 0 ..< keypointImages.count {
            for y in 0 ..< scale.size.height {
                for x in 0 ..< scale.size.width  {
                    if let keypoint = keypointAt(x: x, y: y, s: s) {
                        keypoints.append(keypoint)
                    }
                }
            }
        }
        return keypoints
    }
    
    private func keypointAt(x: Int, y: Int, s: Int) -> SIFTKeypoint? {
        let image = keypointImages[s]
        let output = image[x, y]
        let extrema = output[0] == 1
        let value = output[1]

        if extrema == false {
            return nil
        }

        let keypoint = SIFTKeypoint(
            octave: scale.o,
            scale: s + 1,
            subScale: 0,
            scaledCoordinate: SIMD2<Int>(
                x: x,
                y: y
            ),
            absoluteCoordinate: SIMD2<Float>(
                x: Float(x) * scale.delta,
                y: Float(y) * scale.delta
            ),
            sigma: scale.sigmas[s + 1],
            value: value
        )
        return keypoint
    }
}

