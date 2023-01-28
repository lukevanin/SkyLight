//
//  MetalExtensions.swift
//  SkyLight
//
//  Created by Luke Van In on 2023/01/25.
//

import Foundation
import Metal
import MetalPerformanceShaders


//
//extension CGImage {
//
//    func resizeImage(width targetWidth: Int, height targetHeight: Int) -> CGImage {
//        let sourceWidth = width
//        let sourceHeight = height
//        let sourceAspect = CGFloat(sourceWidth) / CGFloat(sourceHeight)
//        let targetAspect = CGFloat(targetWidth) / CGFloat(targetHeight)
//        let origin: CGPoint
//        if targetAspect > sourceAspect {
//            // Target is wider than source. Resize source to width.
//            let scaledSourceHeight = CGFloat(sourceHeight) / targetAspect
//            origin = CGPoint(
//                x: 0,
//                y: -(scaledSourceHeight - CGFloat(targetHeight)) * 0.5
//            )
//        }
//        else if targetAspect < sourceAspect {
//            // Target is taller than source. Resize source to height.
//            fatalError("not implemented")
//        }
//        else {
//            // Target and source are same aspect.
//            origin = .zero
//        }
//        let size = CGSize(width: targetWidth, height: targetHeight)
//        let rect = CGRect(origin: origin, size: size)
//        let context = CGContext(
//            data: nil,
//            width: targetWidth,
//            height: targetHeight,
//            bitsPerComponent: bitsPerComponent,
//            bytesPerRow: targetWidth * (bitsPerPixel / 8),
//            space: colorSpace!,
//            bitmapInfo: bitmapInfo.rawValue
//        )!
//        context.draw(self, in: rect)
//        return context.makeImage()!
//    }
//}


final class ImageResizer {
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let imageScale: MPSImageBilinearScale
    
    init(device: MTLDevice) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        self.imageScale = MPSImageBilinearScale(device: device)
    }
    
    func resizeTexture(texture inputTexture: MTLTexture, width: Int, height: Int) -> MTLTexture {
        let textureDescriptor = {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: inputTexture.pixelFormat,
                width: width,
                height: height,
                mipmapped: false
            )
            descriptor.usage = [.shaderRead, .shaderWrite]
            descriptor.storageMode = .shared
            descriptor.hazardTrackingMode = .tracked
            return descriptor
        }()
        let outputTexture = device.makeTexture(descriptor: textureDescriptor)!
        
        let commandBuffer = commandQueue.makeCommandBuffer()!

        imageScale.encode(
            commandBuffer: commandBuffer,
            sourceTexture: inputTexture,
            destinationTexture: outputTexture
        )
                
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        return outputTexture
    }
}
