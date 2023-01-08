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
            let extremaFunction = SIFTExtremaFunction(device: device)
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
//        let interpolatedKeypoints = interpolateKeypoints(
//            keypoints: allKeypoints
//        )
        return interpolatedKeypoints
    }
    
    private func findKeypoints(inputTexture: MTLTexture) {
        logger.info("findKeypoints")
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
        logger.info("findKeypoints: Command buffer \(String(format: "%0.3f", elapsedTime)) seconds")
    }
    
    private func getKeypointsFromOctaves() -> [[SIFTKeypoint]] {
        // TODO: Sort keypoints by octave
        var output = [[SIFTKeypoint]]()
        for octave in octaves {
            octave.updateImagesFromTextures()
            let keypoints = octave.getKeypoints()
            output.append(keypoints)
        }
        return output
    }
    
    private func interpolateKeypoints(keypointOctaves: [[SIFTKeypoint]]) -> [[SIFTKeypoint]] {
        var output = [[SIFTKeypoint]]()
        for o in 0 ..< keypointOctaves.count {
            let keypoints = keypointOctaves[o]
            output.append(octaves[o].interpolateKeypoints(
                commandQueue: commandQueue,
                keypoints: keypoints
            ))
        }
        return output
    }

    
    // MARK: Descriptora
    
    func getDescriptors(keypointOctaves: [[SIFTKeypoint]]) -> [[SIFTDescriptor]] {
        precondition(keypointOctaves.count == octaves.count)
        let output = zip(octaves, keypointOctaves).map { octave, keypoints in
            let orientations = octave.getKeypointOrientations(
                commandQueue: commandQueue,
                keypoints: keypoints
            )
            return octave.getDescriptors(
                commandQueue: commandQueue,
                keypoints: keypoints,
                orientations: orientations
            )
        }
        return output
    }
    
    /*
    func getDescriptors(keypointOctaves: [[SIFTKeypoint]]) -> [SIFTDescriptor] {
        var output = [SIFTDescriptor]()
        let orientationOctaves = getPrincipalOrientations(keypointOctaves: keypointOctaves)
        for o in 0 ..< keypointOctaves.count {
            let keypoints = keypointOctaves[o]
            let keypointOrientations = orientationOctaves[o]
            precondition(keypointOrientations.count == keypoints.count)
            for k in 0 ..< keypoints.count {
                let keypoint = keypoints[k]
                let orientations = keypointOrientations[k]
                for theta in orientations {
                    if let descriptor = makeDescriptor(keypoint: keypoint, theta: theta) {
                        output.append(descriptor)
                    }
                }
            }
        }
        return output
    }
    
    private func getPrincipalOrientations(keypointOctaves: [[SIFTKeypoint]]) -> [[[Float]]] {
        var output = [[[Float]]]()
        for o in 0 ..< keypointOctaves.count {
            let keypoints = keypointOctaves[o]
            let orientations = octaves[o].getKeypointOrientations(
                commandQueue: commandQueue,
                keypoints: keypoints
            )
            output.append(orientations)
        }
        return output
    }
    
    private func makeDescriptor(keypoint: SIFTKeypoint, theta: Float) -> SIFTDescriptor? {
        let octave = dog.octaves[keypoint.octave]
        // let images = octave.gaussianImages
        // let histogramsPerAxis = configuration.descriptorHistogramsPerAxis
        let bins = configuration.descriptorOrientationBins
        let image = octaves[keypoint.octave].gradientImages[keypoint.scale]
        
        // let delta = octave.delta
        // let lambda = configuration.lambdaDescriptor
        // let a = keypoint.absoluteCoordinate
        let p = SIMD2<Float>(
            x: Float(keypoint.absoluteCoordinate.x) / octave.delta,
            y: Float(keypoint.absoluteCoordinate.y) / octave.delta
        )

        // Check that the keypoint is sufficiently far from the edge to include
        // entire area of the descriptor.
        
        #warning("TODO: Do this check after interpolation to avoid wasting work on extracting the orientation")
        // let diagonal = Float(2).squareRoot() * lambda * sigma
        // let f = Float(histogramsPerAxis + 1) / Float(histogramsPerAxis)
        // let side = Int((diagonal * f).rounded())
        
        //let radius = lambda * f
        let d = 4 // width of 2d array of histograms
        let cosT = cos(theta)
        let sinT = sin(theta)
        let binsPerRadian = Float(bins) / (2 * .pi)
        let exponentDenominator = Float(d * d) * 0.5
        let interval = Float(keypoint.scale) + keypoint.subScale
        let intervals = Float(dog.configuration.numberOfScalesPerOctave)
        let sigma = Float(1.6)
        let scale = sigma * pow(2.0, interval / intervals) // identical to below
        let _sigma = keypoint.sigma / octave.delta // identical to above
        let histogramWidth = 3.0 * scale // 3.0 constant from Whess (OpenSIFT)
        let radius: Int = Int(histogramWidth * Float(2).squareRoot() * (Float(d) + 1) * 0.5 + 0.5)
        
        let minX = Int(radius)
        let minY = Int(radius)
        let maxX = Int(octave.size.width - 1 - radius)
        let maxY = Int(octave.size.height - 1 - radius)
        
        guard Int(p.x) > minX else {
            return nil
        }
        guard Int(p.y) > minY else {
            return nil
        }
        guard Int(p.x) < maxX else {
            return nil
        }
        guard Int(p.y) < maxY else {
            return nil
        }

        // Create histograms
        let patch = SIFTPatch(side: d, bins: bins)
        
//        for j in 0 ..< d {
//            for i in 0 ..< d {
//                for k in 0 ..< bins {
//                patch.addValue(x: Float(i), y: Float(j), bin: bins - 0.5, value: 1)
//                }
//            }
//        }
//        patch.addValue(x: 0.5, y: 0, bin: 0, value: 1)

        for j in -radius ... +radius {
            for i in -radius ... +radius {
                
                let r = SIMD2<Float>(
                    x: (Float(j) * cosT - Float(i) * sinT) / histogramWidth,
                    y: (Float(j) * sinT + Float(i) * cosT) / histogramWidth
                )
                let b = SIMD2<Float>(
                    x: r.x + Float(d / 2) - 0.5,
                    y: r.y + Float(d / 2) - 0.5
                )
                // print(String(format: "%0.3f %0.3f", b.x, b.y))

                let g = image[Int(p.x) + j, Int(p.y) + i]
                var orientation = g.orientation - theta
                while orientation < 0 {
                    orientation += 2 * .pi
                }
                while orientation > 2 * .pi {
                    orientation -= 2 * .pi
                }

                // Bin
                let bin = orientation * binsPerRadian

                // Total contribution
                let exponentNumerator = r.x * r.x + r.y * r.y
                let w = exp(-exponentNumerator / exponentDenominator)
                let c = g.magnitude * w
                
                patch.addValue(x: b.x, y: b.y, bin: bin, value: c)
            }
        }
        
        // print("feature x=\(Int(a.x)) y=\(Int(a.y)) scale=\(scale) sigma=\(_sigma) histogramWidth=\(histogramWidth) radius=\(radius)")
        
        // Serialize histograms into array
        let f0 = patch.features()
        // print("features: raw", f0.map { String(format: "%0.5f", $0) })
        
        let f1 = normalize(f0)
        // print("features: normalized", f1.map { String(format: "%0.5f", $0) })

        let f2 = normalize(threshold(f1, 0.2))
        // print("features: threshold", f2.map { String(format: "%0.5f", $0) })
        
        let f3 = quantizeFeatures(f2)
        // print("features (quantized)", f3)

        return SIFTDescriptor(
            keypoint: keypoint,
            theta: theta,
            rawFeatures: f2,
            features: f3
        )
    }
    
    private func normalize(_ input: [Float]) -> [Float] {
        var magnitude = Float(0)
        for i in input {
            magnitude += (i * i)
        }
        let d = 1.0 / sqrt(magnitude)
        return input.map { $0 * d }
    }
    
    private func threshold(_ input: [Float], _ threshold: Float) -> [Float] {
        input.map { min($0, threshold) }
    }
    
    private func quantizeFeatures(_ features: [Float]) -> [Int] {
        features.map {
            Int(min(255, ($0 * 512)))
        }
    }
     */
}
