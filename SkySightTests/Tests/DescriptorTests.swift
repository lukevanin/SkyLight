//
//  DescriptorTests.swift
//  SkySightTests
//
//  Created by Luke Van In on 2022/12/26.
//

import XCTest

@testable import SkySight


final class DescriptorTests: SharedTestCase {
    
    func testDescriptors() throws {
        
        let inputTexture = try device.loadTexture(name: "butterfly", extension: "png", srgb: false)
        let configuration = SIFT.Configuration(
            inputSize: IntegralSize(
                width: inputTexture.width,
                height: inputTexture.height
            )
        )
        let subject = SIFT(device: device, configuration: configuration)
        let keypoints = subject.getKeypoints(inputTexture)
        let foundDescriptors = subject.getDescriptors(keypoints: keypoints)
        print("Found", foundDescriptors.count, "descriptors")

        let referenceImage: CGImage = {
            let originalImage = CIImage(
                mtlTexture: inputTexture,
                options: [
                    CIImageOption.colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                ]
            )!
                .oriented(.downMirrored)
                .smearColor()
            let cgImage = ciContext.makeCGImage(ciImage: originalImage)
            return cgImage
        }()

        let referenceDescriptors = try loadDescriptors(filename: "butterfly-descriptors")

        attachImage(
            name: "descriptors",
            uiImage: drawDescriptors(
                sourceImage: referenceImage,
                referenceDescriptors: referenceDescriptors,
                foundDescriptors: foundDescriptors
            )
        )

//        for (scale, octave) in subject.octaves.enumerated() {
//
//            for (index, texture) in octave.keypointTextures.enumerated() {
//
//                attachImage(
//                    name: "keypoints(\(scale), \(index))",
//                    uiImage: ciContext.makeUIImage(
//                        ciImage: CIImage(
//                            mtlTexture: texture,
//                            options: [
//                                .colorSpace: CGColorSpace(name: CGColorSpace.genericGrayGamma2_2)!
//                            ]
//                        )!
//                            .oriented(.downMirrored)
//                            .smearColor()
//                    )
//                )
//            }
//
//        }
        
    }
    
    
    private func loadDescriptors(filename: String, extension: String = "txt") throws -> [SIFTDescriptor] {
        var descriptors = [SIFTDescriptor]()
        
        let fileURL = bundle.url(forResource: filename, withExtension: `extension`)!
        let data = try Data(contentsOf: fileURL)
        let string = String(data: data, encoding: .utf8)!
        let lines = string.split(separator: "\n")
        
        for line in lines {
            let components = line.split(separator: " ")
            guard components.count > 0 else {
                continue
            }
            let y = Float(components[0])!
            let x = Float(components[1])!
            let s = Float(components[2])!
            let theta = Float(components[3])!
            let descriptor = SIFTDescriptor(
                keypoint: SIFTKeypoint(
                    octave: 0,
                    scale: 0,
                    subScale: 0,
                    scaledCoordinate: .zero,
                    absoluteCoordinate: SIMD2<Float>(x: x, y: y),
                    sigma: s,
                    value: 0
                ),
                theta: theta
            )
            descriptors.append(descriptor)
        }
        
        return descriptors
    }
    
}
