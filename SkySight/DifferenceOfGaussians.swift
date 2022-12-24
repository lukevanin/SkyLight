//
//  DifferenceOfGaussians.swift
//  SkySight
//
//  Created by Luke Van In on 2022/12/20.
//

import Foundation
import OSLog
import Metal
import MetalPerformanceShaders


private let logger = Logger(subsystem: "com.lukevanin", category: "DifferenceOfGaussians")


final class DifferenceOfGaussians {
    
    
    struct Configuration {
        
        // Dimensions of the original image.
        var inputDimensions: IntegralSize
        
        // Blur level of v(1, 0) (seed image). Note that the blur level of
        // v(0, 0) will be higher.
        var sigmaMinimum: Float = 0.8
        
        // The sampling distance in image v(0, 1) (see image). The value 0.5
        // corresponds to a 2× interpolation.
        var deltaMinimum: Float = 0.5
        
        // Assumed blur level in uInput (input image).
        var sigmaInput: Float = 0.5
        
        // Number of octaves (limited by the image size )).
        // ⌊log2(min(w, h) / deltaMin / 12) + 1⌋
        var numberOfOctaves: Int = 5
        
        // Number of scales per octave.
        // Number of gaussians per octave = scales per octave + 3.
        // Number of differences per octave = scales per octave + 2
        var numberOfScalesPerOctave: Int = 3
    }
    
    
    final class Octave {
        
        let o: Int
        
        let gaussianTextures: [MTLTexture]
        let differenceTextures: [MTLTexture]
        
        private let scaleFunction: NearestNeighborHalfScaleKernel
        private let gaussianBlurFunctions: [MPSImageGaussianBlur]
        private let subtractFunction: MPSImageSubtract
        
        init(
            device: MTLDevice,
            o: Int,
            size: IntegralSize,
            numberOfScales: Int,
            gaussianBlurFunctions: [MPSImageGaussianBlur],
            scaleFunction: NearestNeighborHalfScaleKernel
        ) {

            let numberOfGaussians = numberOfScales + 2
            let numberOfDifferences = numberOfScales + 1
            
            let textureDescriptor: MTLTextureDescriptor = {
                let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                    pixelFormat: .r32Float,
                    width: size.width,
                    height: size.height,
                    mipmapped: false
                )
                descriptor.usage = [.shaderRead, .shaderWrite]
                descriptor.storageMode = .shared
                return descriptor
            }()

            self.o = o
            self.gaussianBlurFunctions = gaussianBlurFunctions
            self.scaleFunction = scaleFunction

            self.gaussianTextures = {
                var textures = [MTLTexture]()
                for _ in 0 ..< numberOfGaussians {
                    let texture = device.makeTexture(descriptor: textureDescriptor)!
                    textures.append(texture)
                }
                return textures
            }()

            self.differenceTextures = {
                var textures = [MTLTexture]()
                for _ in 0 ..< numberOfDifferences {
                    let texture = device.makeTexture(descriptor: textureDescriptor)!
                    textures.append(texture)
                }
                return textures
            }()
            
            self.subtractFunction = {
                let function = MPSImageSubtract(device: device)
                return function
            }()
        }
        
        func encode(commandBuffer: MTLCommandBuffer, inputTexture: MTLTexture) {
            encodeFirstGaussianTexture(
                commandBuffer: commandBuffer,
                inputTexture: inputTexture
            )
            
            encodeOtherGaussianTextures(commandBuffer: commandBuffer)

            encodeDifferenceTextures(commandBuffer: commandBuffer)
        }
        
        private func encodeFirstGaussianTexture(
            commandBuffer: MTLCommandBuffer,
            inputTexture: MTLTexture
        ) {
            #warning("TODO: Use nearest neighbor scaling")
            logger.info("Encoding gaussian v(\(self.o), 0)")
            let sourceSize = IntegralSize(
                width: inputTexture.width,
                height: inputTexture.height
            )
            let targetSize = IntegralSize(
                width: gaussianTextures[0].width,
                height: gaussianTextures[0].height
            )
            if sourceSize.width == targetSize.width && sourceSize.height == targetSize.height {
                logger.debug("Copy input texture from \(sourceSize.width)x\(sourceSize.height) to \(targetSize.width)x\(targetSize.height)")
                let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
                blitEncoder.copy(from: inputTexture, to: gaussianTextures[0])
                blitEncoder.endEncoding()
            }
            else {
                logger.debug("Scale input texture from \(sourceSize.width)x\(sourceSize.height) to \(targetSize.width)x\(targetSize.height)")
                scaleFunction.encode(
                    commandBuffer: commandBuffer,
                    inputTexture: inputTexture,
                    outputTexture: gaussianTextures[0]
                )
            }
        }
        
        private func encodeOtherGaussianTextures(commandBuffer: MTLCommandBuffer) {
            for i in 1 ..< gaussianTextures.count {
                logger.info("Encoding gaussian v(\(self.o), \(i))")
                gaussianBlurFunctions[i - 1].encode(
                    commandBuffer: commandBuffer,
                    sourceTexture: gaussianTextures[i - 1],
                    destinationTexture: gaussianTextures[i]
                )
            }
        }
        
        private func encodeDifferenceTextures(commandBuffer: MTLCommandBuffer) {
            for i in 0 ..< differenceTextures.count {
                logger.info("Encoding difference w(\(self.o), \(i))")
                subtractFunction.encode(
                    commandBuffer: commandBuffer,
                    primaryTexture: gaussianTextures[i + 1],
                    secondaryTexture: gaussianTextures[i],
                    destinationTexture: differenceTextures[i]
                )
            }
        }
    }
    
    
    let configuration: Configuration
    
    let luminosityTexture: MTLTexture
    let scaledTexture: MTLTexture
    let seedTexture: MTLTexture
    let octaves: [Octave]

    private let colorConversionFunction: MPSImageConversion
    private let bilinearScaleFunction: MPSImageBilinearScale
    private let seedGaussianBlurFunction: MPSImageGaussianBlur
    private let scaleGaussianBlurFunctions: [MPSImageGaussianBlur]
    
    init(device: MTLDevice, configuration: Configuration) {
        
        let seedSize = IntegralSize(
            width: Int(Float(configuration.inputDimensions.width) / configuration.deltaMinimum),
            height: Int(Float(configuration.inputDimensions.height) / configuration.deltaMinimum)
        )
        
        self.configuration = configuration
        
        self.colorConversionFunction = {
            let conversionInfo = CGColorConversionInfo(
//                src: CGColorSpace(name: CGColorSpace.genericRGBLinear)!,
//                src: CGColorSpace(name: CGColorSpace.linearSRGB)!,
                src: CGColorSpace(name: CGColorSpace.sRGB)!,
//                src: CGColorSpaceCreateDeviceRGB(),
//                dst: CGColorSpace(name: CGColorSpace.genericGrayGamma2_2)!
                dst: CGColorSpace(name: CGColorSpace.linearGray)!
//                dst: CGColorSpaceCreateDeviceGray()
            )
            let shader = MPSImageConversion(
                device: device,
                srcAlpha: .alphaIsOne,
                destAlpha: .alphaIsOne,
                backgroundColor: nil,
                conversionInfo: conversionInfo
            )
            return shader
        }()

        self.bilinearScaleFunction = {
            let function = MPSImageBilinearScale(device: device)
            function.edgeMode = .clamp
            return function
        }()

        let nearestNeighborScaleFunction = {
            let function = NearestNeighborHalfScaleKernel(device: device)
            return function
        }()

        self.seedGaussianBlurFunction = {
            let h = 1.0 / configuration.deltaMinimum
            let i = configuration.sigmaMinimum * configuration.sigmaMinimum
            let j = configuration.sigmaInput * configuration.sigmaInput
            let k = h * sqrt(i - j)
            print("𝜎(1, 0)", "=", k)
            let function = MPSImageGaussianBlur(device: device, sigma: k)
            function.edgeMode = .clamp
            return function
        }()

        let scaleGaussianBlurFunctions = {
            let numberOfGaussians = configuration.numberOfScalesPerOctave + 2
            let numberOfScales = configuration.numberOfScalesPerOctave
            var functions = [MPSImageGaussianBlur]()
            for s in 1 ..< numberOfGaussians {
                let h = configuration.sigmaMinimum / configuration.deltaMinimum
                let i = Float(s) / Float(numberOfScales)
                let j = Float(s - 1) / Float(numberOfScales)
                let k = pow(2, 2 * i) - pow(2, 2 * j)
                let rho = h * sqrt(k)
                print(
                    "𝜌[\(s - 1) → \(s)]", "=", rho
                )
                let function = MPSImageGaussianBlur(
                    device: device,
                    sigma: rho
                )
                function.edgeMode = .clamp
                functions.append(function)
            }
            return functions
        }()
        self.scaleGaussianBlurFunctions = scaleGaussianBlurFunctions

        let inputTextureDescriptor: MTLTextureDescriptor = {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .r32Float,
                width: configuration.inputDimensions.width,
                height: configuration.inputDimensions.height,
                mipmapped: false
            )
            descriptor.usage = [.shaderRead, .shaderWrite]
            descriptor.storageMode = .shared
            return descriptor
        }()

        let seedTextureDescriptor: MTLTextureDescriptor = {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .r32Float,
                width: seedSize.width,
                height: seedSize.height,
                mipmapped: false
            )
            descriptor.usage = [.shaderRead, .shaderWrite]
            descriptor.storageMode = .shared
            return descriptor
        }()

        self.luminosityTexture = {
            let texture = device.makeTexture(
                descriptor: inputTextureDescriptor
            )!
            return texture
        }()

        self.scaledTexture = {
            let texture = device.makeTexture(
                descriptor: seedTextureDescriptor
            )!
            return texture
        }()

        self.seedTexture = {
            let texture = device.makeTexture(
                descriptor: seedTextureDescriptor
            )!
            return texture
        }()
        
        self.octaves = {
            var octaves = [Octave]()
            for o in 0 ..< configuration.numberOfOctaves {
                let delta = configuration.deltaMinimum * pow(2, Float(o))
                let size = IntegralSize(
                    width: Int(Float(configuration.inputDimensions.width) / delta),
                    height: Int(Float(configuration.inputDimensions.height) / delta)
                )
                print("octave", o, "dimensions", "=", size)
                let octave = Octave(
                    device: device,
                    o: o,
                    size: size,
                    numberOfScales: configuration.numberOfScalesPerOctave,
                    gaussianBlurFunctions: scaleGaussianBlurFunctions,
                    scaleFunction: nearestNeighborScaleFunction
                )
                octaves.append(octave)
            }
            return octaves
        }()
    }
    
    func encode(
        commandBuffer: MTLCommandBuffer,
        originalTexture: MTLTexture
    ) {
        encodeSeedTexture(
            commandBuffer: commandBuffer,
            inputTexture: originalTexture
        )
        encodeOctaves(commandBuffer: commandBuffer)
    }
    
    private func encodeSeedTexture(
        commandBuffer: MTLCommandBuffer,
        inputTexture: MTLTexture
    ) {
        let inputSize = IntegralSize(
            width: inputTexture.width,
            height: inputTexture.height
        )
        let outputSize = IntegralSize(
            width: scaledTexture.width,
            height: scaledTexture.height
        )

        logger.debug("v(1, 0) Convert texture to grayscale")
        colorConversionFunction.encode(
            commandBuffer: commandBuffer,
            sourceTexture: inputTexture,
            destinationTexture: luminosityTexture
        )

        logger.debug("v(1, 0) Scale texture from \(inputSize.width)x\(inputSize.height) to \(outputSize.width)x\(outputSize.height)")
        bilinearScaleFunction.encode(
            commandBuffer: commandBuffer,
            sourceTexture: luminosityTexture,
            destinationTexture: scaledTexture
        )

        logger.debug("v(1, 0) Blur texture")
        seedGaussianBlurFunction.encode(
            commandBuffer: commandBuffer,
            sourceTexture: scaledTexture,
            destinationTexture: seedTexture
        )
    }

    private func encodeOctaves(commandBuffer: MTLCommandBuffer) {
        logger.debug("Encode octave 0")
        octaves[0].encode(
            commandBuffer: commandBuffer,
            inputTexture: seedTexture
        )
        
        for i in 1 ..< octaves.count {
            logger.debug("Encode octave \(i)")
            octaves[i].encode(
                commandBuffer: commandBuffer,
                inputTexture: octaves[i - 1].gaussianTextures[configuration.numberOfScalesPerOctave]
            )
        }
    }
}
