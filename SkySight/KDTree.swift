//
//  KDTree.swift
//  SkySight
//
//  Created by Luke Van In on 2023/01/16.
//

import Foundation


struct Vector: Equatable {
    let count: Int
    let components: [Float]
    
    init(_ components: [Float]) {
        self.components = components
        self.count = components.count
    }
    
    func distanceSquared(to other: Vector) -> Float {
        zip(components, other.components).reduce(into: 0) {
            $0 += (($1.1 - $1.0) * ($1.1 - $1.0))
        }
    }
    
    func distance(to other: Vector) -> Float {
        sqrt(distanceSquared(to: other))
    }
}


final class KDTree: Equatable {
    
    struct Node: Identifiable, Equatable {
        let id: Int
        let coordinate: Vector
    }
    
    /// Dimensionality (number of components in the value vector).
    let k: Int
    
    /// Depth (depth of the node within the tree).
    private(set) var d: Int
    
    /// Identifier of the node used for the pivot.
    let id: Int
    
    /// "Location" of the pivot point which this node indicates.
    let location: Vector
    
    /// Children on the left of the pivot
    var leftChild: KDTree? {
        didSet {
            leftChild?.d = d + 1
        }
    }
    
    /// Children on the right of the pivot
    var rightChild: KDTree? {
        didSet {
            rightChild?.d = d + 1
        }
    }

    convenience init?<C>(nodes: C, d: Int = 0) where C: Collection, C.Element == Node {
        guard nodes.count > 0 else {
            return nil
        }
        let k = nodes.first!.coordinate.count
        let axis = d % k
        let sorted = nodes.sorted { $0.coordinate.components[axis] < $1.coordinate.components[axis] }
        let medianIndex = sorted.count / 2
        let medianElement = sorted[medianIndex]
        let leftElements = sorted.prefix(upTo: medianIndex)
        let rightElements = sorted.suffix(from: medianIndex + 1)
        self.init(
            id: medianElement.id,
            location: medianElement.coordinate,
            d: d,
            leftChild: KDTree(nodes: leftElements, d: d + 1),
            rightChild: KDTree(nodes: rightElements, d: d + 1)
        )
    }
    
    init(id: Int, location: Vector, d: Int = 0, leftChild: KDTree? = nil, rightChild: KDTree? = nil) {
        if let leftChild {
            precondition(leftChild.d == d + 1)
            precondition(leftChild.k == location.count)
        }
        if let rightChild {
            precondition(rightChild.d == d + 1)
            precondition(rightChild.k == location.count)
        }
        self.id = id
        self.location = location
        self.leftChild = leftChild
        self.rightChild = rightChild
        self.k = location.count
        self.d = d
    }
    
    func find(query: Vector, d: Int = 0) -> Node? {
        if query == location {
            return Node(id: id, coordinate: location)
        }
        let axis = d % k
        let queryComponent = query.components[axis]
        let checkComponent = location.components[axis]
        if queryComponent < checkComponent {
            return leftChild?.find(query: query, d: d + 1)
        }
        else {
            return rightChild?.find(query: query, d: d + 1)
        }
    }
    
    static func == (lhs: KDTree, rhs: KDTree) -> Bool {
        lhs.id == rhs.id &&
        lhs.k == rhs.k &&
        lhs.d == rhs.d &&
        lhs.location == rhs.location &&
        lhs.leftChild == rhs.leftChild &&
        lhs.rightChild == rhs.rightChild
    }

}
