//
//  Image.swift
//  SkySight
//
//  Created by Luke Van In on 2022/12/19.
//

import Foundation
import Metal


final class Image<T> {
    
    private let texture: MTLTexture
    private let buffer: UnsafeMutableBufferPointer<T>
    
    init(texture: MTLTexture, defaultValue: T) {
        self.texture = texture
        self.buffer = {
            let capacity = texture.width * texture.height
            let buffer = UnsafeMutableBufferPointer<T>.allocate(
                capacity: capacity
            )
            buffer.initialize(repeating: defaultValue)
            return buffer
        }()
    }
    
    deinit {
        buffer.deallocate()
    }
    
    func updateFromTexture() {
        let region = MTLRegion(
            origin: MTLOrigin(
                x: 0,
                y: 0,
                z: 0
            ),
            size: MTLSize(
                width: texture.width,
                height: texture.height,
                depth: 1
            )
        )
        let bytesPerComponent = MemoryLayout<T>.stride
        let bytesPerRow = bytesPerComponent * texture.width
        let pointer = UnsafeMutableRawPointer(buffer.baseAddress)!
        texture.getBytes(
            pointer,
            bytesPerRow: bytesPerRow,
            from: region,
            mipmapLevel: 0
        )
    }
    
    subscript(x: Int, y: Int) -> T {
        get {
            buffer[offset(x: x, y: y)]
        }
        set {
            buffer[offset(x: x, y: y)] = newValue
        }
    }
    
    private func offset(x: Int, y: Int) -> Int {
        precondition(x >= 0 && y >= 0 && x <= texture.width - 1 && y <= texture.height - 1)
        return (y * texture.width) + x
    }
}

extension Image where T == Float {
    
    func getGradient(at coordinate: SIMD2<Int>) -> SIMD2<Float> {
        #warning("FIXME: IPOL implementation seems to swap dx and dy")
        let py: Float = self[coordinate.x + 1, coordinate.y]
        let my: Float = self[coordinate.x - 1, coordinate.y]
        let px: Float = self[coordinate.x, coordinate.y + 1]
        let mx: Float = self[coordinate.x, coordinate.y - 1]
        return SIMD2<Float>(x: (px - mx) * 0.5, y: (py - my) * 0.5)
    }
}
