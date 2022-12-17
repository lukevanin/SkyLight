//
//  LucasKanade.swift
//  SkySight
//
//  Created by Luke Van In on 2022/12/17.
//

import UIKit
import Metal
import MetalPerformanceShaders


struct Snapshot {
    let oldImage: CGImage
    let newImage: CGImage
    let ixImage: CGImage
    let iyImage: CGImage
    let itImage: CGImage
    let vImage: CGImage
    let visualizationImage: UIImage
}


final class LucasKanade {
    
    struct Image {
        let inputTexture0: MTLTexture
        let inputTexture1: MTLTexture
        let outputTexture0: MTLTexture
    }

    private let sourceSize: MTLSize
    private let outputSize: MTLSize

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    
    private let textureCache: CVMetalTextureCache
    
    private let aImage: Image
    private let bImage: Image

    private let outputTexture: MTLTexture
    private let ixTexture: MTLTexture
    private let iyTexture: MTLTexture
    private let itTexture: MTLTexture

    private let rgbCIContext: CIContext
    private let grayCIContext: CIContext

    private let imageConversionKernel: MPSImageConversion
    private let blurKernel: MPSImageGaussianBlur
    private let scaleKernel: MPSImageLanczosScale
    private let xSobelKernel: MPSImageConvolution
    private let ySobelKernel: MPSImageConvolution
    private let subtractKernel: MPSImageSubtract
    
    private let lucasKanadePipeline: MTLComputePipelineState

    init(sourceSize: MTLSize, outputSize: MTLSize) {
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let grayColorSpace = CGColorSpaceCreateDeviceGray()
        
        self.sourceSize = sourceSize
        self.outputSize = outputSize
        self.device = MTLCreateSystemDefaultDevice()!
        self.commandQueue = device.makeCommandQueue()!
        
        var textureCache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
        self.textureCache = textureCache!
        
        let inputTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r16Float,
            width: sourceSize.width,
            height: sourceSize.height,
            mipmapped: false
        )
        inputTextureDescriptor.usage = [.shaderRead, .shaderWrite]
        inputTextureDescriptor.storageMode = .shared
        
        let workingTextureDescriptor: MTLTextureDescriptor = {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .r32Float,
                width: outputSize.width,
                height: outputSize.height,
                mipmapped: false
            )
            descriptor.usage = [.shaderRead, .shaderWrite]
            descriptor.storageMode = .shared
            return descriptor
        }()

        let outputTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rg32Float,
            width: outputSize.width,
            height: outputSize.height,
            mipmapped: false
        )
        outputTextureDescriptor.usage = [.shaderRead, .shaderWrite]
        outputTextureDescriptor.storageMode = .shared

        self.aImage = Image(
            inputTexture0: device.makeTexture(
                descriptor: inputTextureDescriptor
            )!,
            inputTexture1: device.makeTexture(
                descriptor: inputTextureDescriptor
            )!,
            outputTexture0: device.makeTexture(
                descriptor: workingTextureDescriptor
            )!
        )

        self.bImage = Image(
            inputTexture0: device.makeTexture(
                descriptor: inputTextureDescriptor
            )!,
            inputTexture1: device.makeTexture(
                descriptor: inputTextureDescriptor
            )!,
            outputTexture0: device.makeTexture(
                descriptor: workingTextureDescriptor
            )!
        )
        
        ixTexture = device.makeTexture(
            descriptor: workingTextureDescriptor
        )!
        iyTexture = device.makeTexture(
            descriptor: workingTextureDescriptor
        )!
        itTexture = device.makeTexture(
            descriptor: workingTextureDescriptor
        )!
        outputTexture = device.makeTexture(
            descriptor: outputTextureDescriptor
        )!


        let conversionInfo = CGColorConversionInfo(
            src: rgbColorSpace,
            dst: grayColorSpace
        )
        self.imageConversionKernel = MPSImageConversion(
            device: device,
            srcAlpha: .alphaIsOne,
            destAlpha: .alphaIsOne,
            backgroundColor: nil,
            conversionInfo: conversionInfo
        )

        self.blurKernel = MPSImageGaussianBlur(device: device, sigma: 5.0)
        self.blurKernel.edgeMode = .clamp
        
        self.scaleKernel = MPSImageLanczosScale(device: device)
        
        var gxWeights: [Float] = [
            +1,  0, -1,
            +2,  0, -2,
            +1,  0, -1,
        ]
        var gyWeights: [Float] = [
            +1, +2, +1,
             0,  0,  0,
            -1, -2, -1,
        ]
        self.xSobelKernel = MPSImageConvolution(
            device: device,
            kernelWidth: 3,
            kernelHeight: 3,
            weights: &gxWeights
        )
        self.xSobelKernel.edgeMode = .clamp
        self.ySobelKernel = MPSImageConvolution(
            device: device,
            kernelWidth: 3,
            kernelHeight: 3,
            weights: &gyWeights
        )
        self.ySobelKernel.edgeMode = .clamp
        self.subtractKernel = MPSImageSubtract(device: device)
        self.subtractKernel.primaryEdgeMode = .clamp
        self.subtractKernel.secondaryEdgeMode = .clamp
        
        // let libraryURL = Bundle.main.url(forResource: "Shaders", withExtension: "metal")!
        let library = device.makeDefaultLibrary()!
        let lucasKanadeFunction = library.makeFunction(name: "lucasKanade")!
        self.lucasKanadePipeline = try! device.makeComputePipelineState(function: lucasKanadeFunction)

        self.rgbCIContext = CIContext(
            mtlDevice: device,
            options: [
                .useSoftwareRenderer: false,
                .outputColorSpace: rgbColorSpace,
                .workingColorSpace: rgbColorSpace,
            ]
        )

        self.grayCIContext = CIContext(
            mtlDevice: device,
            options: [
                .useSoftwareRenderer: false,
                .outputColorSpace: grayColorSpace,
                .workingColorSpace: grayColorSpace,
            ]
        )
    }
    
    func perform(_ aImageBuffer: CVImageBuffer, _ bImageBuffer: CVImageBuffer) -> Snapshot {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        
        // Convert to grayscale, resize, and blur
        preprocessTexture(
            commandBuffer: commandBuffer,
            input: makeTexture(aImageBuffer),
            image: aImage
        )
        
        preprocessTexture(
            commandBuffer: commandBuffer,
            input: makeTexture(bImageBuffer),
            image: bImage
        )

        //   let Ix = image1.convolved(with: Sobel_x)
        xSobelKernel.encode(
            commandBuffer: commandBuffer,
            sourceTexture: aImage.outputTexture0,
            destinationTexture: ixTexture
        )
        // let Iy = image1.convolved(with: Sobel_y)
        ySobelKernel.encode(
            commandBuffer: commandBuffer,
            sourceTexture: aImage.outputTexture0,
            destinationTexture: iyTexture
        )
        // let It = image2 - image1
        subtractKernel.encode(
            commandBuffer: commandBuffer,
            primaryTexture: bImage.outputTexture0,
            secondaryTexture: aImage.outputTexture0,
            destinationTexture: itTexture
        )
        
        // Lucas-Kanade
        let computeEncoder = commandBuffer.makeComputeCommandEncoder()!
        computeEncoder.setComputePipelineState(lucasKanadePipeline)
        computeEncoder.setTexture(outputTexture, index: 0)
        computeEncoder.setTexture(ixTexture, index: 1)
        computeEncoder.setTexture(iyTexture, index: 2)
        computeEncoder.setTexture(itTexture, index: 3)

        // Set the compute kernel's threadgroup size of 16x16
        let threadgroupSize = MTLSize(
            width: 16,
            height: 16,
            depth: 1
        )
        // Calculate the number of rows and columns of threadgroups given the width of the input image
        // Ensure that you cover the entire image (or more) so you process every pixel
        // Since we're only dealing with a 2D data set, set depth to 1
        let threadgroupCount = MTLSize(
            width: (outputSize.width + threadgroupSize.width - 1) / threadgroupSize.width,
            height: (outputSize.height + threadgroupSize.height - 1) / threadgroupSize.height,
            depth: 1
        )
        computeEncoder.dispatchThreadgroups(
            threadgroupCount,
            threadsPerThreadgroup: threadgroupSize
        )
        computeEncoder.endEncoding()

        // Commit
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Make output
        return Snapshot(
            oldImage: makeCGImage(aImageBuffer, context: rgbCIContext),
            newImage: makeCGImage(bImageBuffer, context: rgbCIContext),
            ixImage: makeCGImage(ixTexture, context: grayCIContext),
            iyImage: makeCGImage(iyTexture, context: grayCIContext),
            itImage: makeCGImage(itTexture, context: grayCIContext),
            vImage: makeCGImage(outputTexture, context: rgbCIContext),
            visualizationImage: makeVisualization(
                reference: makeCGImage(bImageBuffer, context: rgbCIContext),
                vectors: outputTexture
            )
        )
    }
    
    private func makeVisualization(reference: CGImage, vectors: MTLTexture) -> UIImage {
        
        let inputWidth = vectors.width
        let inputHeight = vectors.height
        
        let outputWidth = sourceSize.width / 2
        let outputHeight = sourceSize.height / 2
        let grid = 5
        let scale = Float32(20)
        
        let backgroundColor = UIColor.systemGreen.withAlphaComponent(0.5)
        let zoneColor = UIColor.white.withAlphaComponent(0.5)
        let lineColor = UIColor.systemPink

        
        let region = MTLRegion(
            origin: MTLOrigin(x: 0, y: 0, z: 0),
            size: MTLSize(width: inputWidth, height: inputHeight, depth: 1)
        )
        let bytesPerComponent = MemoryLayout<simd_packed_float2>.stride
        let bytesPerRow = bytesPerComponent * inputWidth
        // let totalBytes = bytesPerRow * texture.height

        var textureData = Array<simd_packed_float2>(
            repeating: simd_packed_float2.zero,
            count: inputWidth * inputHeight
        )
        vectors.getBytes(
            &textureData,
            bytesPerRow: bytesPerRow,
            from: region,
            mipmapLevel: 0
        )
        

        let size = CGSize(width: outputWidth, height: outputHeight)
        let bounds = CGRect(origin: .zero, size: size)
        
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        let imageRenderer = UIGraphicsImageRenderer(
            bounds: bounds,
            format: format
        )
        let image = imageRenderer.image { context in
            
            let cgContext = context.cgContext
            cgContext.setShouldAntialias(false)
            cgContext.setAllowsAntialiasing(false)
            
            cgContext.saveGState()
            cgContext.scaleBy(x: 1, y: -1)
            cgContext.translateBy(x: 0, y: -size.height)
            cgContext.draw(reference, in: bounds)
            cgContext.restoreGState()
            
            cgContext.saveGState()
            cgContext.setFillColor(backgroundColor.cgColor)
            cgContext.fill([bounds])
            cgContext.restoreGState()
            
//            let sx = inputWidth / grid
//            let sy = inputHeight / grid
            
            let k = 5
            let minX: Int = k
            let minY: Int = k
            let maxX: Int = inputWidth - 1 - k
            let maxY: Int = inputHeight - 1 - k
            let deltaX = maxX - minX
            let deltaY = maxY - minY
            
            let scaleX = Float(outputWidth) / Float(inputWidth)
            let scaleY = Float(outputHeight) / Float(inputHeight)
            
            var aDirection = simd_float2(0, 0)
            var aCount = 0

            for j in 0 ..< grid {
                
                for i in 0 ..< grid {
                    
                    let ox = Float(minX) + ((Float(i) / Float(grid)) * Float(deltaX))
                    let oy = Float(minY) + ((Float(j) / Float(grid)) * Float(deltaY))
                    
                    var direction = simd_float2(0, 0)
                    var count = Float(0)
                    
                    for v in -k ... +k {
                        
                        for u in -k ... +k {
                            
                            let dx = Int((ox + Float(u)).rounded())
                            let dy = Int((oy + Float(v)).rounded())
                            
                            let offset = (dy * inputWidth) + dx
                            direction += textureData[offset]
                            count += 1
                        }
                    }
                    
                    direction = direction / count
                    let length = simd_length(direction)
                    
                    guard length > 0.0001 else {
                        continue
                    }

                    aDirection += direction
                    aCount += 1

//                    print("flow", "dx", dx, "dy", dy, "=", length)
//                    let vector = (simd_normalize(direction) * 2) +
                    let vector = direction * scale

                    let origin = simd_packed_float2(
                        x: (ox * scaleX).rounded(),
                        y: (oy * scaleY).rounded()
                    )
                    let start = CGPoint(origin)
                    let end = CGPoint(origin + vector)
                    

                    cgContext.saveGState()
                    cgContext.setFillColor(zoneColor.cgColor)
                    cgContext.fillEllipse(
                        in: CGRect(
                            x: CGFloat(origin.x) - (CGFloat(scale) * 0.5),
                            y: CGFloat(origin.y) - (CGFloat(scale) * 0.5),
                            width: CGFloat(scale),
                            height: CGFloat(scale)
                        )
                    )
                    cgContext.restoreGState()

                    cgContext.saveGState()
                    cgContext.move(to: start)
                    cgContext.addLine(to: end)
                    cgContext.setLineWidth(5)
                    cgContext.setStrokeColor(lineColor.cgColor)
                    cgContext.strokePath()
                    cgContext.restoreGState()

                    // let percent = Double((y * sx) + x) / Double(sx * sy)
                    // print(String(format: "%0.3f%% %0.3f %0.3f %0.3f", percent * 100, direction.x, direction.y, length))
                }
            }
            
            let radius = Float(100)
            let center = CGPoint(
                x: CGFloat(outputWidth) * 0.5,
                y: CGFloat(outputHeight) * 0.5
            )
            let heading = CGPoint((aDirection / Float(aCount)) * radius)
            let end = CGPoint(
                x: center.x + heading.x,
                y: center.y + heading.y
            )
            
            cgContext.saveGState()
            cgContext.setFillColor(zoneColor.cgColor)
            cgContext.fillEllipse(
                in: CGRect(
                    x: center.x - CGFloat(radius),
                    y: center.y - CGFloat(radius),
                    width: CGFloat(radius) * 2,
                    height: CGFloat(radius) * 2
                )
            )
            cgContext.restoreGState()

            cgContext.saveGState()
            cgContext.move(to: center)
            cgContext.addLine(to: end)
            cgContext.setLineWidth(5)
            cgContext.setStrokeColor(lineColor.cgColor)
            cgContext.strokePath()
            cgContext.restoreGState()

        }
        
        return image
    }
    
    private func makeCGImage(_ input: CVImageBuffer, context: CIContext) -> CGImage {
        let ciImage = CIImage(
            cvPixelBuffer: input,
            options: [.applyOrientationProperty: true]
        )
        return makeCGImage(ciImage, context: context)
    }
    
    private func makeCGImage(_ input: MTLTexture, context: CIContext) -> CGImage {
        let ciImage = CIImage(mtlTexture: input)!
        return makeCGImage(ciImage, context: context)
    }
    
    private func makeCGImage(_ input: CIImage, context: CIContext) -> CGImage {
        return context.createCGImage(input, from: input.extent)!
    }
    
    private func makeTexture(_ input: CVImageBuffer) -> MTLTexture {
        var cvMetalTexture: CVMetalTexture?
        let result = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, input, nil, .bgra8Unorm, sourceSize.width, sourceSize.height, 0, &cvMetalTexture)
        guard result == kCVReturnSuccess else {
            fatalError("Cannot create texture")
        }
        let texture = CVMetalTextureGetTexture(cvMetalTexture!)!
        return texture
    }
    
    private func preprocessTexture(commandBuffer: MTLCommandBuffer, input: MTLTexture, image: Image) {
        
        imageConversionKernel.encode(
            commandBuffer: commandBuffer,
            sourceTexture: input,
            destinationTexture: image.inputTexture0
        )

        blurKernel.encode(
            commandBuffer: commandBuffer,
            sourceTexture: image.inputTexture0,
            destinationTexture: image.inputTexture1
        )

        scaleKernel.encode(
            commandBuffer: commandBuffer,
            sourceTexture: image.inputTexture1,
            destinationTexture: image.outputTexture0
        )
    }
}
