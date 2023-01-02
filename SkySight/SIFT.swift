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
    // Index of the level of the difference-of-gaussians pyramid.
    var octave: Int
    // Index of the image in the octave.
    var scale: Int
    //
    var subScale: Float
    // Coordinate relative to the difference-of-gaussians image size.
    var scaledCoordinate: SIMD2<Int>
    // Coordinate relative to the original image.
    var absoluteCoordinate: SIMD2<Float>
    // "Blur"
    var sigma: Float
    // Pixel color (intensity)
    var value: Float
}


struct SIFTDescriptor {
    // Detected keypoint.
    let keypoint: SIFTKeypoint
    // Principal orientation.
    let theta: Float
}


typealias SIFTHistogram = [Float]


final class SIFTOctave {
    
    let scale: DifferenceOfGaussians.Octave
    
    let keypointTextures: [MTLTexture]
    let images: [Image<SIMD2<Float>>]
    
    private let extremaFunction: SIFTExtremaFunction
    
    init(
        device: MTLDevice,
        scale: DifferenceOfGaussians.Octave,
        extremaFunction: SIFTExtremaFunction
    ) {
        
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
            var images = [Image<SIMD2<Float>>]()
            for texture in keypointTextures {
                let image = Image<SIMD2<Float>>(texture: texture, defaultValue: .zero)
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
        for s in 0 ..< images.count {
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
        let image = images[s]
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

    // MARK: Keypoints
    
    func getKeypoints(_ inputTexture: MTLTexture) -> [SIFTKeypoint] {
        findKeypoints(inputTexture: inputTexture)
        let allKeypoints = getKeypointsFromOctaves()
        let interpolatedKeypoints = interpolateKeypoints(
            keypoints: allKeypoints
        )
        return interpolatedKeypoints
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

    private func interpolateKeypoints(keypoints: [SIFTKeypoint]) -> [SIFTKeypoint] {
        var interpolatedKeypoints = [SIFTKeypoint]()
        
        for octave in dog.octaves {
            for image in octave.differenceImages {
                image.updateFromTexture()
            }
            
            for image in octave.gaussianImages {
                image.updateFromTexture()
            }
        }
        
        for i in 0 ..< keypoints.count {
            let keypoint = keypoints[i]
            let interpolatedKeypoint = interpolateKeypoint(keypoint: keypoint)
            if let interpolatedKeypoint {
                interpolatedKeypoints.append(interpolatedKeypoint)
            }
        }
        return interpolatedKeypoints
    }
    
    private func interpolateKeypoint(keypoint: SIFTKeypoint) -> SIFTKeypoint? {
        
        guard abs(keypoint.value) > configuration.differenceOfGaussiansThreshold * 0.8 else {
            return nil
        }
        
        // Note: x and y are swapped in the original algorithm.
        
        // Maximum number of consecutive unsuccessful interpolation.
        let maximumIterations: Int = configuration.maximumInterpolationIterations
        
        let maximumOffset: Float = 0.6
        
        // Ratio between two consecutive scales in the scalespace assuming the
        // ratio is constant over all scales and over all octaves.
        let sigmaRatio = dog.octaves[0].sigmas[1] / dog.octaves[0].sigmas[0]
        
        let o: Int = keypoint.octave
        let s: Int = keypoint.scale
        let x: Int = keypoint.scaledCoordinate.x
        let y: Int = keypoint.scaledCoordinate.y
        let octave: DifferenceOfGaussians.Octave = dog.octaves[o]
        let delta: Float = octave.delta
        let images: [Image<Float>] = octave.differenceImages
        
        var coordinate = SIMD3<Int>(x: x, y: y, z: s)
        
        // Check coordinates are within the scale space.
        guard !outOfBounds(octave: octave, coordinate: coordinate) else {
            print("keypoint \(coordinate): rejected: out of bounds")
            return nil
        }

        var converged = false
        var alpha: SIMD3<Float> = .zero
        
        var i = 0
        while i < maximumIterations {
            alpha = interpolationStep(images: images, coordinate: coordinate)
            
            if (abs(alpha.x) < maximumOffset) && (abs(alpha.y) < maximumOffset) && (abs(alpha.z) < maximumOffset) {
                converged = true
                break
            }
            
            // Whess
            // coordinate.x += Int(alpha.x.rounded())
            // coordinate.y += Int(alpha.y.rounded())
            // coordinate.z += Int(alpha.z.rounded())
            
            // IPOL
            if (alpha.x > +maximumOffset) {
                coordinate.x += 1
            }
            if (alpha.x < -maximumOffset) {
                coordinate.x -= 1
            }
            if (alpha.y > +maximumOffset) {
                coordinate.y += 1
            }
            if (alpha.y < -maximumOffset) {
                coordinate.y -= 1
            }
            if (alpha.z > +maximumOffset) {
                coordinate.z += 1
            }
            if (alpha.z < -maximumOffset) {
                coordinate.z -= 1
            }
            
            // Check coordinates are within the scale space.
            guard !outOfBounds(octave: octave, coordinate: coordinate) else {
                print("keypoint \(coordinate): rejected: interpolated out of bounds")
                return nil
            }
            
            i += 1
        }
        
        guard converged == true else {
            return nil
        }
        
        let newValue = interpolateContrast(i: images, c: coordinate, alpha: alpha)
        
        guard abs(newValue) > configuration.differenceOfGaussiansThreshold else {
            print("keypoint \(coordinate): rejected: low contrast=\(newValue)")
            return nil
        }
        
        // Discard keypoint with high edge response
        let isOnEdge = self.isOnEdge(images: images, coordinate: coordinate)
        guard !isOnEdge else {
            print("keypoint \(coordinate): rejected: on edge")
            return nil
        }
        
        let sigma = octave.sigmas[s] * pow(sigmaRatio, alpha.z)
        let absoluteCoordinate = SIMD2<Float>(
            x: (Float(coordinate.x) + alpha.x) * delta,
            y: (Float(coordinate.y) + alpha.y) * delta
        )
        
        // Discard keypoint that lies too close to the boundary.
//        let isCloseToBoundary = self.isCloseToBoundary(
//            sigma: sigma,
//            coordinate: absoluteCoordinate,
//            delta: delta
//        )
//        guard !isCloseToBoundary else {
//            print("keypoint \(coordinate): rejected: close to boundary")
//            return nil
//        }

        print("keypoint \(coordinate): accepted: \(i) out of \(maximumIterations): alpha=\(alpha) value=\(newValue)")
        
        // intvl = ddata->intvl + ddata->subintvl;
        // feat->scl = sigma * pow( 2.0, ddata->octv + intvl / intvls );
        // ddata->scl_octv = sigma * pow( 2.0, intvl / intvls );
        
        // Return keypoint
        return SIFTKeypoint(
            octave: keypoint.octave,
            scale: coordinate.z,
            subScale: alpha.z,
            scaledCoordinate: SIMD2<Int>(
                x: coordinate.x,
                y: coordinate.y
            ),
            absoluteCoordinate: absoluteCoordinate,
            sigma: sigma,
            value: newValue
        )
    }
    
    private func outOfBounds(octave: DifferenceOfGaussians.Octave, coordinate: SIMD3<Int>) -> Bool {
        let minX = configuration.imageBorder
        let maxX = octave.size.width - configuration.imageBorder - 1
        let minY = configuration.imageBorder
        let maxY = octave.size.height - configuration.imageBorder - 1
        let minS = 1
        let maxS = octave.numberOfScales
        return coordinate.x < minX || coordinate.x > maxX || coordinate.y < minY || coordinate.y > maxY || coordinate.z < minS || coordinate.z > maxS
    }
    
    private func interpolationStep(
        images: [Image<Float>],
        coordinate: SIMD3<Int>
    ) -> SIMD3<Float> {
        
        let H = hessian3D(i: images, c: coordinate)
        precondition(H.determinant != 0)
        let Hi = -H.inverse.transpose
        
        let dD = derivatives3D(i: images, c: coordinate)
        
        let x = Hi * dD
        
        return x
    }
    
    ///
    /// Computes the 3D Hessian matrix.
    ///
    ///```
    ///  ⎡ Ixx Ixy Ixs ⎤
    ///
    ///    Ixy Iyy Iys
    ///
    ///  ⎣ Ixs Iys Iss ⎦
    /// ```
    ///
    private func hessian3D(i: [Image<Float>], c: SIMD3<Int>) -> matrix_float3x3 {
        let v = i[c.z][c.x, c.y]
        
        let dxx = i[c.z][c.x + 1, c.y] + i[c.z][c.x - 1, c.y] - 2 * v
        let dyy = i[c.z][c.x, c.y + 1] + i[c.z][c.x, c.y - 1] - 2 * v
        let dss = i[c.z + 1][c.x, c.y] + i[c.z - 1][c.x, c.y] - 2 * v

        let dxy = (i[c.z][c.x + 1, c.y + 1] - i[c.z][c.x - 1, c.y + 1] - i[c.z][c.x + 1, c.y - 1] + i[c.z][c.x - 1, c.y - 1]) * 0.25
        let dxs = (i[c.z + 1][c.x + 1, c.y] - i[c.z + 1][c.x - 1, c.y] - i[c.z - 1][c.x + 1, c.y] + i[c.z - 1][c.x - 1, c.y]) * 0.25
        let dys = (i[c.z + 1][c.x, c.y + 1] - i[c.z + 1][c.x, c.y - 1] - i[c.z - 1][c.x, c.y + 1] + i[c.z - 1][c.x, c.y - 1]) * 0.25
        
        return matrix_float3x3(
            rows: [
                SIMD3<Float>(dxx, dxy, dxs),
                SIMD3<Float>(dxy, dyy, dys),
                SIMD3<Float>(dxs, dys, dss),
            ]
        )
    }
    
    ///
    /// Computes interpolated contrast. Based on Eqn. (3) in Lowe's paper.
    ///
    func interpolateContrast(i: [Image<Float>], c: SIMD3<Int>, alpha: SIMD3<Float>) -> Float {
        let dD = derivatives3D(i: i, c: c)
        let t = dD * alpha
        let v = i[c.z][c.x, c.y] + t.x * 0.5
        return v
    }
    
    ///
    /// Computes the partial derivatives in x, y, and scale of a pixel in the DoG scale space pyramid.
    ///
    /// - Returns: Returns the vector of partial derivatives for pixel I { dI/dX, dI/dY, dI/ds }ᵀ
    ///
    private func derivatives3D(i: [Image<Float>], c: SIMD3<Int>) -> SIMD3<Float> {
        return SIMD3<Float>(
            x: (i[c.z][c.x + 1, c.y] - i[c.z][c.x - 1, c.y]) * 0.5,
            y: (i[c.z][c.x, c.y + 1] - i[c.z][c.x, c.y - 1]) * 0.5,
            z: (i[c.z + 1][c.x, c.y] - i[c.z - 1][c.x, c.y]) * 0.5
        )
    }

    ///
    /// Compute Edge response
    ///
    /// Determines whether a feature is too edge like to be stable by computing the ratio of principal
    /// curvatures at that feature.  Based on Section 4.1 of Lowe's paper.
    ///
    /// i.e.  Compute the ratio of principal curvatures
    /// Compute the ratio (hXX + hYY)*(hXX + hYY)/(hXX*hYY - hXY*hXY);
    ///
    /// The 2D hessian of the DoG operator is computed via finite difference schemes.
    ///
    private func isOnEdge(images: [Image<Float>], coordinate c: SIMD3<Int>) -> Bool {
        let i = images[c.z]
        let v = i[c.x, c.y]
        
        // Compute the 2d Hessian at pixel (i,j) - i = y, j = x
        // IPOL implementation uses hxx for y axis, and hyy for x axis
        let hxx = i[c.x, c.y - 1] + i[c.x, c.y + 1] - 2 * v
        let hyy = i[c.x + 1, c.y] + i[c.x - 1, c.y] - 2 * v
        let hxy = ((i[c.x + 1, c.y + 1] - i[c.x - 1, c.y + 1]) - (i[c.x + 1, c.y - 1] - i[c.x - 1, c.y - 1])) * 0.25
        
        // Whess
        let trace = hxx + hyy
        let determinant = (hxx * hyy) - (hxy * hxy)
        
        guard determinant > 0 else {
            // Negative determinant -> curvatures have different signs
            return true
        }
        
        let edgeThreshold = configuration.edgeThreshold
        let threshold = ((edgeThreshold + 1) * (edgeThreshold + 1)) / edgeThreshold
        let curvature = (trace * trace) / determinant
        
        guard curvature < threshold else {
            // Feature is on an edge
            return true
        }
        
        // Feature is not on an edge
        return false
        
        // let edgeThreshold = pow(threshold + 1, 2) / configuration.edgeThreshold

        // IPOL
        // Harris and Stephen Edge response
        // let edgeResponse = (hxx + hyy) * (hxx + hyy) / (hxx * hyy - hxy * hxy)
        // return edgeResponse
    }
    
    ///
    /// Determines whether the keypoint is within the allowed distance from the boundary of the image. A
    /// keypoint that lies too close to the edge cannot be used to extract a feature descriptor.
    ///
//    func isCloseToBoundary(sigma s: Float, coordinate c: SIMD2<Int>, delta: Float) -> Bool {
//        let size = configuration.inputSize
//        let s = s / delta
//        let r = (3 * configuration.lambdaOrientation * s).rounded(.up)
//        let w = Float(size.width) / delta
//        let h = Float(size.height) / delta
//        let p = SIMD2<Float>(
//            x: Float(c.x) / delta,
//            y: Float(c.y) / delta
//        )
//        let minX = r
//        let minY = r
//        let maxX = w - r - 1
//        let maxY = h - r - 1
//        return (p.x < minX) || (p.x > maxX) || (p.y < minY) || (p.y > maxY)
//    }
    
    // MARK: Descriptora
    
    func getDescriptors(keypoints: [SIFTKeypoint]) -> [SIFTDescriptor] {
        var output = [SIFTDescriptor]()
        for i in 0 ..< keypoints.count {
            let keypoint = keypoints[i]
            let descriptors = makeDescriptors(keypoint: keypoint)
            output.append(contentsOf: descriptors)
        }

//        if let keypoint = keypoints.first {
//            let descriptor = makeDescriptors(keypoint: keypoint)
//            output.append(contentsOf: descriptor)
//        }
        return output
    }
    
    private func makeDescriptors(keypoint: SIFTKeypoint) -> [SIFTDescriptor] {
        let orientations = getPrincipalOrientations(keypoint: keypoint)
        return orientations.map { theta in
            return SIFTDescriptor(keypoint: keypoint, theta: theta)
        }
    }
    
    private func getPrincipalOrientations(keypoint: SIFTKeypoint) -> [Float] {
        guard let histogram = getOrientationsHistogram(from: keypoint) else {
            return []
        }
        let orientations = getPrincipalOrientations(from: histogram)
        return orientations
    }
    
    private func getOrientationsHistogram(from keypoint: SIFTKeypoint) -> SIFTHistogram? {
        let octave = dog.octaves[keypoint.octave]
        // TODO: Use keypoint.scaledCoordinate (but first update scaledCoordinate to include alpha)
        let x = Int(Float(keypoint.absoluteCoordinate.x) / octave.delta)
        let y = Int(Float(keypoint.absoluteCoordinate.y) / octave.delta)
        let sigma = keypoint.sigma / octave.delta
//        let scale = Float(keypoint.scale) + keypoint.subScale
//        let image = octave.gaussianImages[Int(scale.rounded())]
        let image = octave.gaussianImages[keypoint.scale]

        let lambda = configuration.lambdaOrientation
        let exponentDenominator = 2 * lambda * lambda
        
        let r = Int((3 * lambda * sigma).rounded(.up))
        
        let bins = configuration.orientationBins
        var histogram = Array<Float>(repeating: 0, count: bins)
        
        let minX = 1
        let minY = 1
        let maxX = octave.size.width - 2
        let maxY = octave.size.height - 2
        
        guard x - r >= minX else {
            return nil
        }
        guard x + r <= maxX else {
            return nil
        }
        guard y - r >= minY else {
            return nil
        }
        guard y + r <= maxY else {
            return nil
        }
        
//        print("x=\(x) y=\(y) sigma=\(sigma.formatted())")

//        print("histogram at \(x),\(y) radius=\(r) ")
        for j in -r ... r {
            for i in -r ... r {

                // Gaussian weighting
//                let u = Float(i) / Float(r)
//                let v = Float(j) / Float(r)
                let u = Float(i) / sigma
                let v = Float(j) / sigma
                let r2 = Float(u * u + v * v)
                let w = exp(-r2 / exponentDenominator)

                // Gradient orientation
                let c = SIMD2<Int>(x: x + i, y: y + j)
                let d = image.getGradient(at: c)
                let orientation = atan2(d.y, d.x)
                let magnitude = sqrt(d.x * d.x + d.y * d.y)
                
                // Add to histogram
                let t = orientation / (2 * .pi)
                var bin = Int((t * Float(bins)).rounded())
                if bin >= bins {
                    bin -= bins
                }
                if bin < 0 {
                    bin += bins
                }
                
                let m = (w * magnitude)
                // printf( si, sj, sX, sY, r2, dx, dy, ori, gamma, M);
//                print("\(c.x),\(c.y) \(u.formatted()),\(v.formatted()) (r=\(r2.formatted())): dx=\(d.x.formatted()) dy=\(d.y.formatted()) orientation=\(orientation.formatted()) bin=\(bin) w=\(w.formatted()) value=\(m.formatted())")
                
                histogram[bin] += m
//                print("\(i),\(j): \(bin) += \(w)")
            }
        }
        
//        print("histogram=\(histogram)")
        return histogram
    }
    
    private func getPrincipalOrientations(from histogram: [Float]) -> [Float] {
        var orientations = [Float]()
        let histogram = smoothHistogram(histogram: histogram)
        let maximum = histogram.max()!
        let n = configuration.orientationBins
        let threshold = configuration.orientationThreshold * maximum
        for i in 0 ..< n {
            let hm = histogram[((i - 1) + n) % n]
            let h0 = histogram[i]
            let hp = histogram[(i + 1) % n]
            guard (h0 > threshold) && (h0 > hm) && (h0 > hp) else {
                continue
            }
            let offset = interpolatePeak(hm, h0, hp)
            let orientation = orientationFromBin(Float(i) + offset)
            orientations.append(orientation)
        }
//        print("found \(orientations.count) principal orientations")
        return orientations
    }
    
    private func smoothHistogram(histogram: [Float]) -> [Float] {
        let n = histogram.count
        let iterations = configuration.orientationSmoothingIterations
        var output = histogram
        for _ in 0 ..< iterations {
            let temp = output
            for i in 0 ..< n {
                let h0 = temp[((i - 1) + n) % n]
                let h1 = temp[i]
                let h2 = temp[(i + 1) % n]
                let v = (h0 + h1 + h2) / 3
                output[i] = v
            }
        }
        return output
    }
    
    private func interpolatePeak(_ h1: Float, _ h2: Float, _ h3: Float) -> Float {
        let peak = (h1 - h3) / (2 * (h1 + h3 - 2 * h2))
        return peak
    }
    
    private func binFromOrientation(_ orientation: Float) -> Int {
        let n = configuration.orientationBins
        var o = orientation
        if (o < 0) {
            o += 2 * .pi;
        }
        let b = Int(o / (2 * Float.pi) * Float(n) + 0.5) % n
        return b
    }

    private func orientationFromBin(_ bin: Float) -> Float {
        let n = configuration.orientationBins
        let t = bin / Float(n)
        var orientation = t * 2 * .pi;
        if (orientation > (2 * .pi)) {
            orientation -= 2 * .pi
        }
        if (orientation < 0) {
            orientation += 2 * .pi
        }
        return orientation
    }
}
