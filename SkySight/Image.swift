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

struct Gradient {
    let orientation: Float
    let magnitude: Float
}

extension Image where T == Float {
    
    func getGradient(x: Int, y: Int) -> Gradient {
        #warning("FIXME: IPOL implementation seems to swap dx and dy")
        let g = getGradientVector(x: x, y: y)
        return Gradient(
            orientation: atan2(g.x, g.y),
            magnitude: sqrt(g.x * g.x + g.y * g.y)
        )
    }
    
    func getGradientVector(x: Int, y: Int) -> SIMD2<Float> {
        let px: Float = self[x + 1, y]
        let mx: Float = self[x - 1, y]
        let py: Float = self[x, y + 1]
        let my: Float = self[x, y - 1]
        return SIMD2<Float>(x: (px - mx) * 0.5, y: (py - my) * 0.5)
    }
}
