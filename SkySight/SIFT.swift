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


typealias SIFTHistogram = [Float]



///
/// See: https://github.com/robwhess/opensift/blob/master/src/sift.c
/// See: http://www.ipol.im/pub/art/2014/82/article.pdf
/// See: https://medium.com/jun94-devpblog/cv-13-scale-invariant-local-feature-extraction-3-sift-315b5de72d48
final class SIFT {
    
    struct Configuration {
        
        // Dimensions of the input image.
        var inputSize: IntegralSize
        
        // Threshold over the Difference of Gaussians response (value
        // relative to scales per octave = 3)
        var differenceOfGaussiansThreshold: Float = 0.0133

        // Threshold over the ratio of principal curvatures (edgeness).
        var edgeThreshold: Float = 10.0
        
        // Maximum number of consecutive unsuccessful interpolation.
        var maximumInterpolationIterations: Int = 5
        
        // Width of border in which to ignore keypoints
        var imageBorder: Int = 5
        
        // Sets how local is the analysis of the gradient distribution.
        var lambdaOrientation: Float = 1.5
        
        // Number of bins in the orientation histogram.
        var orientationBins: Int = 36
        
        // Threshold for considering local maxima in the orientation histogram.
        var orientationThreshold: Float = 0.8
        
        // Number of iterations used to smooth the orientation histogram
        var orientationSmoothingIterations: Int = 6
        
        // Number of normalized histograms in the normalized patch in the
        // descriptor. This must be a square integer number so that both x
        // and y axes have the same length.
        var descriptorHistogramsPerAxis: Int = 4
        
        // Number of bins in the descriptor histogram.
        var descriptorOrientationBins: Int = 8
        
        // How local the descriptor is (size of the descriptor).
        // Gaussian window of lambdaDescriptor * sigma
        // Descriptor patch width of 2 * lambdaDescriptor * sigma
        var lambdaDescriptor: Float = 6
    }

    let configuration: Configuration
    let dog: DifferenceOfGaussians
    let octaves: [SIFTOctave]
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    
    init(
        device: MTLDevice,
        configuration: Configuration
    ) {
        self.device = device
        
        let dog = DifferenceOfGaussians(
            device: device,
            configuration: DifferenceOfGaussians.Configuration(
                inputDimensions: configuration.inputSize
            )
        )
        let octaves: [SIFTOctave] = {
            let extremaFunction = SIFTExtremaListFunction(device: device)
            let gradientFunction = SIFTGradientKernel(device: device)

            var octaves = [SIFTOctave]()
            for scale in dog.octaves {
                let octave = SIFTOctave(
                    device: device,
                    scale: scale,
                    extremaFunction: extremaFunction,
                    gradientFunction: gradientFunction
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

    // MARK: Keypoints
    
    func getKeypoints(_ inputTexture: MTLTexture) -> [[SIFTKeypoint]] {
        findKeypoints(inputTexture: inputTexture)
        let keypointOctaves = getKeypointsFromOctaves()
        let interpolatedKeypoints = interpolateKeypoints(keypointOctaves: keypointOctaves)
        return interpolatedKeypoints
    }
    
    private func findKeypoints(inputTexture: MTLTexture) {
        measure(name: "findKeypoints") {
            capture(commandQueue: commandQueue, capture: false) {
                let commandBuffer = commandQueue.makeCommandBuffer()!
                commandBuffer.label = "siftKeypointsCommandBuffer"
                
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
            }
        }
    }
    
    private func getKeypointsFromOctaves() -> [Buffer<SIFTExtremaResult>] {
        var output = [Buffer<SIFTExtremaResult>]()
        measure(name: "getKeypointsFromOctaves") {
            for octave in octaves {
                let keypoints = octave.getKeypoints()
                output.append(keypoints)
            }
        }
        let totalKeypoints = output.reduce(into: 0) { $0 += $1.count }
        logger.info("getKeypointsFromOctaves: Found \(totalKeypoints) keypoints")
        return output
    }
    
    private func interpolateKeypoints(keypointOctaves: [Buffer<SIFTExtremaResult>]) -> [[SIFTKeypoint]] {
        var output = [[SIFTKeypoint]]()
        measure(name: "interpolateKeypoints") {
            for o in 0 ..< keypointOctaves.count {
                let keypoints = keypointOctaves[o]
                output.append(octaves[o].interpolateKeypoints(
                    commandQueue: commandQueue,
                    keypoints: keypoints
                ))
            }
        }
        return output
    }

    
    // MARK: Descriptora
    
    func getDescriptors(keypointOctaves: [[SIFTKeypoint]]) -> [[SIFTDescriptor]] {
        precondition(keypointOctaves.count == octaves.count)
        
        var orientationOctaves = [[SIFTKeypointOrientations]]()
        measure(name: "getDescriptors(orientations)") {
            for i in 0 ..< octaves.count {
                let octave = octaves[i]
                let keypoints = keypointOctaves[i]
                let orientationOctave = octave.getKeypointOrientations(
                    commandQueue: commandQueue,
                    keypoints: keypoints
                )
                orientationOctaves.append(orientationOctave)
            }
        }
        
        var output: [[SIFTDescriptor]] = []
        measure(name: "getDescriptors(descriptors)") {
            for i in 0 ..< octaves.count {
                let octave = octaves[i]
                let orientationOctave = orientationOctaves[i]
                let descriptors = octave.getDescriptors(
                    commandQueue: commandQueue,
                    orientationOctave: orientationOctave
                )
                output.append(descriptors)
            }
        }
//        orientationOctaves.map { orientations in
//            var output = [SIFTDescriptor]()
//            for i in 0 ..< orientations.count {
//                let orientation = orientations[i]
//                for theta in orientation.orientations {
//                    #warning("TODO: Use real descriptor")
//                    let descriptor = SIFTDescriptor(
//                        keypoint: orientation.keypoint,
//                        theta: theta,
//                        rawFeatures: [],
//                        features: Array<Int>(repeating: 0, count: 128)
//                    )
//                    output.append(descriptor)
//                }
//            }
//            return output
//        }
        return output
    }
}
