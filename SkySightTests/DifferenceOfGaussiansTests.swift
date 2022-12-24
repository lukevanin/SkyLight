//
//  DifferenceOfGaussiansTests.swift
//  SkySightTests
//
//  Created by Luke Van In on 2022/12/24.
//

import XCTest
import CoreImage
import CoreImage.CIFilterBuiltins
import MetalKit
import MetalPerformanceShaders

@testable import SkySight


let bundle = Bundle(for: DifferenceOfGaussiansTests.self)


func loadTexture(url: URL, device: MTLDevice) throws -> MTLTexture {
    print("Loading texture \(url)")
    let loader = MTKTextureLoader(device: device)
    return try loader.newTexture(
        URL: url,
        options: [
            .SRGB: NSNumber(value: true),
        ]
    )
}


func loadTexture(name: String, device: MTLDevice) throws -> MTLTexture {
    let imageURL = bundle.url(forResource: name, withExtension: "tiff")!
    return try loadTexture(url: imageURL, device: device)
}


func makeUIImage(texture: MTLTexture, context: CIContext) -> UIImage {
    makeUIImage(ciImage: makeCIImage(texture: texture), context: context)
}


func makeUIImage(ciImage: CIImage, context: CIContext) -> UIImage {
    let cgImage = context.createCGImage(ciImage, from: ciImage.extent)!
    let uiImage = UIImage(cgImage: cgImage)
    return uiImage
}


func makeCIImage(texture: MTLTexture) -> CIImage {
    var ciImage = CIImage(mtlTexture: texture)!
    ciImage = ciImage.transformed(
        by: ciImage.orientationTransform(
            for: .downMirrored
        )
    )
    return ciImage
}



let colorSmearFilter: CIFilter & CIColorMatrix = {
    let filter = CIFilter.colorMatrix()
    filter.rVector = CIVector(x: 1, y: 0, z: 0)
    filter.gVector = CIVector(x: 1, y: 0, z: 0)
    filter.bVector = CIVector(x: 1, y: 0, z: 0)
    filter.biasVector = CIVector(x: 0, y: 0, z: 0)
    return filter
}()


func smearColor(ciImage inputImage: CIImage) -> CIImage {
    colorSmearFilter.inputImage = inputImage
    return colorSmearFilter.outputImage!.cropped(
        to: inputImage.extent
    )
}


let colorNormalizeFilter: CIFilter & CIColorMatrix = {
    let filter = CIFilter.colorMatrix()
    filter.rVector = CIVector(x: 0.5, y: 0, z: 0)
    filter.gVector = CIVector(x: 0.5, y: 0, z: 0)
    filter.bVector = CIVector(x: 0.5, y: 0, z: 0)
    filter.biasVector = CIVector(x: 0.5, y: 0.5, z: 0.5)
    return filter
}()


func normalizeColor(ciImage inputImage: CIImage) -> CIImage {
    colorNormalizeFilter.inputImage = inputImage
    return colorNormalizeFilter.outputImage!.cropped(
        to: inputImage.extent
    )
}



let colorMapFilter: CIFilter & CIColorMap = {
    let imageFileURL = bundle.url(forResource: "viridis", withExtension: "png")!
    let filter = CIFilter.colorMap()
    filter.gradientImage = CIImage(contentsOf: imageFileURL)
    return filter
}()


func mapColor(ciImage inputImage: CIImage) -> CIImage {
    colorMapFilter.inputImage = inputImage
    return colorMapFilter.outputImage!
}


final class DifferenceOfGaussiansTests: XCTestCase {
    
    private var device: MTLDevice!
    private var commandQueue: MTLCommandQueue!
    private var ciContext: CIContext!

    override func setUp() {
        device = MTLCreateSystemDefaultDevice()!
        commandQueue = device.makeCommandQueue()!
        ciContext = CIContext(
            mtlDevice: device,
            options: [
                // .workingColorSpace: CGColorSpaceCreateDeviceRGB(),
                .outputColorSpace: CGColorSpaceCreateDeviceRGB(),
            ]
        )
    }
    
    override func tearDown() {
        ciContext = nil
        commandQueue = nil
        device = nil
    }

    func testComputeDifferenceOfGaussians() throws {
        
        let inputTexture = try loadTexture(name: "butterfly", device: device)
        
        let configuration = DifferenceOfGaussians.Configuration(
            inputDimensions: IntegralSize(
                width: Int(inputTexture.width),
                height: Int(inputTexture.height)
            )
        )
        let subject = DifferenceOfGaussians(
            device: device,
            configuration: configuration
        )
        
        print("Encoding")
        let commandBuffer = commandQueue.makeCommandBuffer()!
        subject.encode(
            commandBuffer: commandBuffer,
            originalTexture: inputTexture
        )
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        print("Saving attachments")
        
        
        attachImage(
            name: "v(1, 0): luminosity",
            uiImage: makeUIImage(
                ciImage: smearColor(
                    ciImage: makeCIImage(
                        texture: subject.luminosityTexture
                    )
                ),
                context: ciContext
            )
        )
        
        attachImage(
            name: "v(1, 0): scaled",
            uiImage: makeUIImage(
                ciImage: smearColor(
                    ciImage: makeCIImage(
                        texture: subject.scaledTexture
                    )
                ),
                context: ciContext
            )
        )

        attachImage(
            name: "v(1, 0): seed",
            uiImage: makeUIImage(
                ciImage: smearColor(
                    ciImage: makeCIImage(
                        texture: subject.seedTexture
                    )
                ),
                context: ciContext
            )
        )

        for (o, octave) in subject.octaves.enumerated() {
            
            for (s, texture) in octave.gaussianTextures.enumerated() {
                
                let uiImage = makeUIImage(
                    texture: texture,
                    context: ciContext
                )
                attachImage(
                    name: "v[\(o), \(s)]",
                    uiImage: makeUIImage(
                        ciImage: smearColor(
                            ciImage: makeCIImage(
                                texture: texture
                            )
                        ),
                        context: ciContext
                    )
                )
            }
            
            for (s, texture) in octave.differenceTextures.enumerated() {
                
                attachImage(
                    name: "w[\(o), \(s)]",
                    uiImage: makeUIImage(
                        ciImage: mapColor(
                            ciImage: normalizeColor(
                                ciImage: smearColor(
                                    ciImage: makeCIImage(
                                        texture: texture
                                    )
                                )
                            )
                        ),
                        context: ciContext
                    )
                )
            }
        }
    }

    func testPerformanceExample() throws {
        self.measure {
        }
    }
    
    private func attachImage(name: String, uiImage: UIImage) {
        let attachment = XCTAttachment(
            image: uiImage,
            quality: .original
        )
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
