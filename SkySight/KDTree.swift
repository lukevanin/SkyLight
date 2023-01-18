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
    
    subscript(index: Int) -> Float {
        components[index]
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
    
    func findExact(query: Vector, d: Int = 0) -> Node? {
        if query == location {
            // Found exact match. Return matching node.
            return Node(id: id, coordinate: location)
        }
        let axis = d % k
        let queryComponent = query[axis]
        let checkComponent = location[axis]
        if queryComponent < checkComponent {
            return leftChild?.findExact(query: query, d: d + 1)
        }
        else {
            return rightChild?.findExact(query: query, d: d + 1)
        }
    }
    
    struct Match: Equatable {
        var id: Int
        var coordinate: Vector
        var distance: Float
    }
    
    func findNearest(query: Vector, d: Int = 0) -> Match {
        if query == location {
            // Exact match.
            return Match(
                id: id,
                coordinate: location,
                distance: 0
            )
        }

        // Find best match
        let axis = d % k
        let queryComponent = query[axis]
        let checkComponent = location[axis]
        let first: KDTree?
        let second: KDTree?
        if queryComponent < checkComponent {
            first = leftChild
            second = rightChild
        }
        else {
            first = rightChild
            second = leftChild
        }
        guard let first else {
            // No first choice.
            guard let second else {
                // No second choice. Use current node as best match.
                return Match(
                    id: id,
                    coordinate: location,
                    distance: query.distance(to: location)
                )
            }
            // Second
            let secondChoiceMatch = second.findNearest(query: query, d: d + 1)
            return secondChoiceMatch
        }

        // Get best match from first child node.
        let firstChoiceMatch = first.findNearest(query: query, d: d + 1)
        
        // If second node is closer than the best match, then find best match
        // from the second node, otherwise return the current best match.
        guard let second else {
            return firstChoiceMatch
        }
        let distanceToSecondChoice = abs(queryComponent - second.location[axis])
        if distanceToSecondChoice > firstChoiceMatch.distance {
            // Second choice is same distance or further than our current match.
            // Use the current match
            return firstChoiceMatch
        }
        // Second choice is closer than our first choice. Look at match from
        // second choice.
        let secondChoiceMatch = second.findNearest(query: query, d: d + 1)
        if secondChoiceMatch.distance > firstChoiceMatch.distance {
            // First choice is still closer. Return the first choice.
            return firstChoiceMatch
        }
        // Second choice is closer than first choice. Return the second
        // choice.
        return secondChoiceMatch
    }

    static func == (lhs: KDTree, rhs: KDTree) -> Bool {
        lhs.id == rhs.id &&
        lhs.d == rhs.d &&
        lhs.location == rhs.location &&
        lhs.leftChild == rhs.leftChild &&
        lhs.rightChild == rhs.rightChild
    }

}
