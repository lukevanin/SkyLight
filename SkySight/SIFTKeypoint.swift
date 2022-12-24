//
//  SIFTKeypoint.swift
//  SkySight
//
//  Created by Luke Van In on 2022/12/20.
//

import Foundation


struct Keypoint {
    let x: Int
    let y: Int
    let sigma: Float
    
    var radius: Float {
        pow(2, sigma)
    }
}
