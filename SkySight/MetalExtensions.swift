//
//  MetalExtensions.swift
//  SkySight
//
//  Created by Luke Van In on 2023/01/10.
//

import Foundation
import Metal

extension MTLCaptureManager {
    func perform(commandQueue: MTLCommandQueue, capture: Bool = true, worker: () -> Void) {
        guard capture else {
            worker()
            return
        }
        let captureDescriptor = MTLCaptureDescriptor()
        captureDescriptor.captureObject = commandQueue
        captureDescriptor.destination = .developerTools
        try! startCapture(with: captureDescriptor)
        worker()
        stopCapture()
    }
}

