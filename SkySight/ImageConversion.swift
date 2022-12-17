//
//  ImageConversion.swift
//  SkySight
//
//  Created by Luke Van In on 2022/12/18.
//

import Foundation
import CoreImage
import CoreVideo
import Metal


final class ImageConversion {
    
    private let ciContext: CIContext
    
    init(device: MTLDevice, colorSpace: CGColorSpace) {
        self.ciContext = CIContext(
            mtlDevice: device,
            options: [
                .useSoftwareRenderer: false,
                .outputColorSpace: colorSpace,
                .workingColorSpace: colorSpace,
            ]
        )
    }

    func makeCGImage(_ input: CVImageBuffer) -> CGImage {
        let ciImage = CIImage(
            cvPixelBuffer: input,
            options: [.applyOrientationProperty: true]
        )
        return makeCGImage(ciImage)
    }
    
    func makeCGImage(_ input: MTLTexture) -> CGImage {
        let ciImage = CIImage(mtlTexture: input)!
        return makeCGImage(ciImage)
    }
    
    func makeCGImage(_ input: CIImage) -> CGImage {
        return ciContext.createCGImage(input, from: input.extent)!
    }

}
