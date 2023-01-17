//
//  KDTree.swift
//  SkySight
//
//  Created by Luke Van In on 2023/01/16.
//

import Foundation


final class KDTree: Equatable {
    
    typealias Vector = [Float]
    
    /// Dimensionality (number of components in the value vector).
    let k: Int
    
    /// Depth (depth of the node within the tree).
    let d: Int
    
    /// "Location" of the pivot point which this node indicates.
    let location: Vector
    
    /// Children on the left of the pivot
    let leftChild: KDTree?
    
    /// Children on the right of the pivot
    let rightChild: KDTree?

    convenience init?<C>(elements: C, k: Int, d: Int = 0) where C: Collection, C.Element == Vector {
        guard elements.count > 0 else {
            return nil
        }
        let axis = d % k
        let sorted = elements.sorted { $0[axis] < $1[axis] }
        let medianIndex = sorted.count / 2
        let leftElements = sorted.prefix(upTo: medianIndex)
        let rightElements = sorted.suffix(from: medianIndex + 1)
        self.init(
            location: sorted[medianIndex],
            leftChild: KDTree(elements: leftElements, k: k, d: d + 1),
            rightChild: KDTree(elements: rightElements, k: k, d: d + 1),
            k: k,
            d: d
        )
    }
    
    init(location: Vector, leftChild: KDTree?, rightChild: KDTree?, k: Int, d: Int) {
        self.location = location
        self.leftChild = leftChild
        self.rightChild = rightChild
        self.k = k
        self.d = d
    }
    
    static func == (lhs: KDTree, rhs: KDTree) -> Bool {
        lhs.k == rhs.k &&
        lhs.d == rhs.d &&
        lhs.location == rhs.location &&
        lhs.leftChild == rhs.leftChild &&
        lhs.rightChild == rhs.rightChild
    }

}
