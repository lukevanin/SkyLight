//
//  LucasKanade.swift
//  SkySight
//
//  Created by Luke Van In on 2022/12/17.
//

import UIKit
import Metal
import MetalPerformanceShaders


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
    
    private let aImage: Image
    private let bImage: Image

    let outputTexture: MTLTexture
    let ixTexture: MTLTexture
    let iyTexture: MTLTexture
    let itTexture: MTLTexture

    private let imageConversionKernel: MPSImageConversion
    private let blurKernel: MPSImageGaussianBlur
    private let scaleKernel: MPSImageLanczosScale
    private let xSobelKernel: MPSImageConvolution
    private let ySobelKernel: MPSImageConvolution
    private let subtractKernel: MPSImageSubtract
    
    private let lucasKanadePipeline: MTLComputePipelineState

    init(device: MTLDevice, sourceSize: MTLSize, outputSize: MTLSize) {
        
        self.sourceSize = sourceSize
        self.outputSize = outputSize
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        
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
            src: CGColorSpaceCreateDeviceRGB(),
            dst: CGColorSpaceCreateDeviceGray()
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
    }
    
    func perform(_ aTexture: MTLTexture, _ bTexture: MTLTexture) {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        
        // Convert to grayscale, resize, and blur
        preprocessTexture(
            commandBuffer: commandBuffer,
            input: aTexture,
            image: aImage
        )
        
        preprocessTexture(
            commandBuffer: commandBuffer,
            input: bTexture,
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
