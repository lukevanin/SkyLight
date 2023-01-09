//
//  Buffer.swift
//  SkySight
//
//  Created by Luke Van In on 2023/01/06.
//

import Foundation
import Metal


final class Buffer<T> {

    let data: MTLBuffer
    let pointer: UnsafeMutablePointer<T>
    let numberOfBytes: Int
    let count: Int

    init(device: MTLDevice, label: String, count: Int) {
        self.count = count
        self.numberOfBytes = MemoryLayout<T>.stride * count
        self.data = device.makeBuffer(length: numberOfBytes, options: [.hazardTrackingModeTracked, .storageModeShared])!
        self.data.label = label
        self.pointer = data.contents().bindMemory(to: T.self, capacity: count)
    }
    
//    deinit {
//        data.setPurgeableState(.empty)
//    }
    
    subscript(i: Int) -> T {
        get {
            precondition(i >= 0 && i < count)
            return pointer[i]
        }
        set {
            precondition(i >= 0 && i < count)
            pointer[i] = newValue
        }
    }
}
