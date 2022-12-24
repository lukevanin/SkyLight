//
//  SIFT.swift
//  SkySight
//
//  Created by Luke Van In on 2022/12/18.
//

import Foundation
import Metal
import MetalPerformanceShaders



/// See: http://www.ipol.im/pub/art/2014/82/article.pdf
/// See: https://medium.com/jun94-devpblog/cv-13-scale-invariant-local-feature-extraction-3-sift-315b5de72d48
final class SIFT {
    
    struct Configuration {
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
        
        // Threshold over the Difference of Gaussians response (value
        // relative to scales per octave = 3)
        var differenceOfGaussiansThreshold: Float = 0.015
        
        // Threshold over the ratio of principal curvatures (edgeness).
        var edgeThreshold: Float = 10.0
    }

    
    let configuration: Configuration

//    let octaves: [SIFTOctave]
    
//    let inputTexture: MTLTexture
//
//    private let colorConversionFunction: MPSImageConversion
//
//    private let device: MTLDevice
//    private let commandQueue: MTLCommandQueue
    
    init(
        device: MTLDevice,
        configuration: Configuration
    ) {
        self.configuration = configuration
            
//        self.device = device
//        self.configuration = configuration
//        self.commandQueue = device.makeCommandQueue()!
        
//        self.colorConversionFunction = {
//            let conversionInfo = CGColorConversionInfo(
//                src: CGColorSpace(name: CGColorSpace.sRGB)!,
//                dst: CGColorSpace(name: CGColorSpace.genericGrayGamma2_2)!
//            )
//            let shader = MPSImageConversion(
//                device: device,
//                srcAlpha: .alphaIsOne,
//                destAlpha: .alphaIsOne,
//                backgroundColor: nil,
//                conversionInfo: conversionInfo
//            )
//            return shader
//        }()
        
//        let textureDescriptor: MTLTextureDescriptor = {
//            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
//                pixelFormat: .r32Float,
//                width: inputSize.width,
//                height: inputSize.height,
//                mipmapped: false
//            )
//            descriptor.usage = [.shaderRead, .shaderWrite]
//            descriptor.storageMode = .shared
//            return descriptor
//        }()
        
//        self.inputTexture = device.makeTexture(
//            descriptor: textureDescriptor
//        )!
        
//        self.octaves = {
//            var output = [SIFTOctave]()
//            for i in 0 ..< configuration.numberOfOctaves {
//                let size = IntegralSize(
//                    width: inputSize.width >> i,
//                    height: inputSize.height >> i
//                )
//                let differenceOfGaussians = DifferenceOfGaussians(
//                    device: device,
//                    size: size,
//                    count: 4,
//                    initialSigma: 1.6 * pow(k, )
//                )
//                let keypoints = SIFTKeypoints(
//                    device: device,
//                    size: size,
//                    count: 2,
//                    differenceOfGaussians: differenceOfGaussians
//                )
//                let octave = SIFTOctave(
//                    device: device,
//                    keypoints: keypoints
//                )
//                output.append(octave)
//            }
//            return output
//        }()
    }
    
    func process(_ inputTexture: MTLTexture) {
        
//        updateOctaves(
//            texture: inputTexture
//        )
//
//        findKeypoints()
    }
    

//    private func updateOctaves(
//        texture: MTLTexture
//    ) {
//        let commandBuffer = commandQueue.makeCommandBuffer()!
//
//        conversionShader.encode(
//            commandBuffer: commandBuffer,
//            sourceTexture: texture,
//            destinationTexture: inputTexture
//        )
//
//        for octave in octaves {
//            octave.update(commandBuffer: commandBuffer, texture: inputTexture)
//        }
//
//        commandBuffer.commit()
//        commandBuffer.waitUntilCompleted()
//
//        let elapsedTime = commandBuffer.gpuEndTime - commandBuffer.gpuStartTime
//        print("Command buffer", String(format: "%0.3f", elapsedTime), "seconds")
//
//        for octave in octaves {
//            octave.updateBuffers()
//        }
//    }

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
