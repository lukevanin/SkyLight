//
//  KDTree.swift
//  SkySight
//
//  Created by Luke Van In on 2023/01/16.
//

import Foundation


struct Vector: Equatable, CustomStringConvertible {
    let count: Int
    let components: [Float]
    
    var description: String {
        let components = components
            .map({ String(format: "%0.3f", $0) })
            .joined(separator: ", ")
        return "<Vector [\(count)] \(components)>"
    }
    
    init(_ components: [Float]) {
        self.components = components
        self.count = components.count
    }
    
    subscript(index: Int) -> Float {
        components[index]
    }
    
    func distanceSquared(to other: Vector) -> Float {
        precondition(count == other.count)
        var k: Float = 0
        for i in 0 ..< count {
            let d = other[i] - self[i]
            k += d * d
        }
        return k
    }
    
    func distance(to other: Vector) -> Float {
        sqrt(distanceSquared(to: other))
    }
}


final class KDTree: Equatable {
    
    struct Node: Identifiable, Equatable, CustomStringConvertible {
        let id: Int
        let coordinate: Vector
        
        var description: String {
            "<Node #\(id) @\(coordinate)>"
        }
    }
    
    /// Dimensionality (number of components in the value vector).
    let k: Int
    
    /// Depth (depth of the node within the tree).
    private(set) var d: Int
    
    /// Identifier of the node used for the pivot.
    let id: Int
    
    /// "Location" of the pivot point which this node indicates.
    let location: Vector
    
    /// Pivot value (location[axis])
    let pivot: Float
    
    /// Axis
    let axis: Int
    
    /// Count
    var searchCountMetric: Int = 0
    
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
        let sorted = nodes.sorted { $0.coordinate[axis] < $1.coordinate[axis] }
        let medianIndex = sorted.count / 2
        let median = sorted[medianIndex].coordinate[axis]
        let splitIndex = (sorted.firstIndex { $0.coordinate[axis] > median } ?? sorted.count) - 1
        let medianElement = sorted[splitIndex]
        // Points on left are less than or equal to the pivot.
        let leftElements = sorted.prefix(upTo: splitIndex)
        // Points on right are strictly greater than the pivot.
        let rightElements = sorted.suffix(from: splitIndex + 1)
        for leftElement in leftElements {
            precondition(leftElement.coordinate[axis] <= medianElement.coordinate[axis])
        }
        for rightElement in rightElements {
            precondition(rightElement.coordinate[axis] > medianElement.coordinate[axis])
        }
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
        self.axis = d % k
        self.pivot = location[axis]
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

    func findNearest(query: Vector) -> Match {
        searchCountMetric = 0
        let bestMatch = Match(
            id: id,
            coordinate: location,
            distance: .greatestFiniteMagnitude
        )
        return findNearest(query: query, currentBestMatch: bestMatch, count: &searchCountMetric)
    }

    private func findNearest(
        query: Vector,
        currentBestMatch: Match,
        count: inout Int
    ) -> Match {
        
        count += 1
        var bestMatch = currentBestMatch

        // Use this node as the best match if it is nearer than the current best.
        let distance = query.distance(to: location)
        if distance < bestMatch.distance {
            bestMatch = Match(
                id: id,
                coordinate: location,
                distance: distance
            )
        }

        // Visit leaf nodes.
        let value = query[axis]
        if value <= pivot {
            // Left first
            if let leftChild, value - bestMatch.distance <= pivot {
                bestMatch = leftChild.findNearest(query: query, currentBestMatch: bestMatch, count: &count)
            }
            if let rightChild, value + bestMatch.distance > pivot {
                bestMatch = rightChild.findNearest(query: query, currentBestMatch: bestMatch, count: &count)
            }
        }
        else {
            // Right first
            if let rightChild, value + bestMatch.distance > pivot {
                bestMatch = rightChild.findNearest(query: query, currentBestMatch: bestMatch, count: &count)
            }
            if let leftChild, value - bestMatch.distance <= pivot {
                bestMatch = leftChild.findNearest(query: query, currentBestMatch: bestMatch, count: &count)
            }
        }

        return bestMatch
    }
    
    private class PriorityQueue {
        
        struct Entry {
            enum Side {
                case left
                case right
            }
            let value: Float
            let pivot: Float
            let distance: Float
            let tree: KDTree
            let side: Side
        }
        
        var isEmpty: Bool {
            entries.isEmpty
        }
        
        private var entries = [Entry]()
        
        func insert(_ entry: Entry) {
            entries.append(entry)
            #warning("TODO: Use binary heap for priority queue")
            entries.sort { $0.distance < $1.distance }
        }
        
        func removeFirst() -> Entry {
            entries.removeFirst()
        }
    }
    
    func findApproximateNearest(query: Vector) -> Match {
        searchCountMetric = 0
        let queue = PriorityQueue()
        var bestMatch = Match(id: id, coordinate: location, distance: .greatestFiniteMagnitude)
        bestMatch = findApproximateNearestLeaf(
            query: query,
            queue: queue,
            bestMatch: bestMatch,
            count: &searchCountMetric
        )
        while queue.isEmpty == false {
            let current = queue.removeFirst()
            let child = current.tree
            let pivot = current.pivot
            let value = current.value
            switch current.side {
            case .left:
                if value + bestMatch.distance <= pivot {
                    continue
                }
            case .right:
                if value - bestMatch.distance > pivot {
                    continue
                }
            }
            let nextMatch = current.tree.findApproximateNearestLeaf(
                query: query,
                queue: queue,
                bestMatch: bestMatch,
                count: &searchCountMetric
            )
            if nextMatch.distance < bestMatch.distance {
                bestMatch = nextMatch
            }
        }
//        print("node visited=\(searchCountMetric)")
        return bestMatch
    }
    
    private func findApproximateNearestLeaf(
        query: Vector,
        queue: PriorityQueue,
        bestMatch: Match,
        count: inout Int
    ) -> Match {

        count += 1
        var bestMatch: Match = bestMatch
        
        // Use this node as the best match if it is nearer than the current best.
        let distance = query.distance(to: location)
        if distance < bestMatch.distance {
            bestMatch = Match(id: id, coordinate: location, distance: distance)
        }
                        
        // Visit leaf nodes.
        let value = query[axis]
        if value <= pivot {
            // Left first
            if let rightChild {
                let entry = PriorityQueue.Entry(
                    value: value,
                    pivot: pivot,
                    distance: abs(value - pivot),
                    tree: rightChild,
                    side: .left
                )
                queue.insert(entry)
            }

            if let leftChild, value - bestMatch.distance <= pivot {
                bestMatch = leftChild.findApproximateNearestLeaf(
                    query: query,
                    queue: queue,
                    bestMatch: bestMatch,
                    count: &count
                )
            }
        }
        else {
            // Right first
            if let leftChild {
                let entry = PriorityQueue.Entry(
                    value: value,
                    pivot: pivot,
                    distance: abs(value - pivot),
                    tree: leftChild,
                    side: .right
                )
                queue.insert(entry)
            }

            if let rightChild, value + bestMatch.distance > pivot {
                bestMatch = rightChild.findApproximateNearestLeaf(
                    query: query,
                    queue: queue,
                    bestMatch: bestMatch,
                    count: &count
                )
            }
        }

        return bestMatch
    }
    
    static func ==(lhs: KDTree, rhs: KDTree) -> Bool {
        lhs.id == rhs.id &&
        lhs.d == rhs.d &&
        lhs.location == rhs.location &&
        lhs.leftChild == rhs.leftChild &&
        lhs.rightChild == rhs.rightChild
    }

}
