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
    
    func update() {
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
        (y * texture.width) + x
    }
}
