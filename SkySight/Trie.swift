//
//  Trie.swift
//  SkySight
//
//  Created by Luke Van In on 2023/01/20.
//

import Foundation


final class Trie {
    
    private(set) var nodeCountMetric = 0
    private(set) var comparisonCountMetric = 0
    
    // Number of bins
    let numberOfBins: Int
    
    // Nodes
    private var nodes: [Trie?]
    
    // Values
    private var values: [FloatVector] = []
    
    private var rightNode: Trie!
    private var leftNode: Trie!
    
    convenience init(numberOfBins: Int) {
        self.init(nodes: Array<Trie?>(repeating: nil, count: numberOfBins))
    }
    
    convenience init(_ nodes: Trie?...) {
        self.init(nodes: nodes)
    }
    
    init(nodes: [Trie?]) {
        self.numberOfBins = nodes.count
        self.nodes = nodes
    }
    
    func capacity() -> Int {
        var total = values.count
        for node in nodes {
            if let node {
                total += node.capacity()
            }
        }
        return total
    }
    
    func link() {
        let nodes = self.leaves()
        for i in 0 ..< nodes.count {
            let thisNode = nodes[i]
            let nextNode = nodes[(i + 1) % nodes.count]
            thisNode.rightNode = nextNode
            nextNode.leftNode = thisNode
        }
        
        for node in nodes {
            precondition(node.leftNode != nil)
            precondition(node.rightNode != nil)
        }
        print("linked", nodes.count, "nodes")
    }
    
    private func leaves() -> [Trie] {
        var leaves: [Trie] = []
        if values.isEmpty {
            // Branch node
            for node in nodes {
                if let node = node {
                    let childLeaves = node.leaves()
                    leaves.append(contentsOf: childLeaves)
                }
            }
        }
        else {
            // Leaf node
            leaves.append(self)
        }
        return leaves
    }

    func insert(_ key: FloatVector) {
        insert(key: ArraySlice(key.components), value: key)
    }
    
    private func insert(key: ArraySlice<Float>, value: FloatVector) {
        #warning("TODO: use loop instead of recursion")
        guard key.count > 0 else {
            values.append(value)
            return
        }
        let prefix = key[key.startIndex]
        let binIndex = binIndex(for: prefix)
        var node: Trie! = nodes[binIndex]
        if node == nil {
            node = Trie(numberOfBins: numberOfBins)
            nodes[binIndex] = node
        }
        let suffix = key.suffix(from: key.startIndex + 1)
        node.insert(key: suffix, value: value)

//        let binIndex = binIndex(for: prefix)
//        let leftBinIndex = self.binIndex(before: binIndex)
//        let rightBinIndex = self.binIndex(after: binIndex)
//        let indices = [leftBinIndex, binIndex, rightBinIndex]

//        for index in indices {
//            var node: Trie! = nodes[index]
//            if node == nil {
//                node = Trie(numberOfBins: numberOfBins)
//                nodes[index] = node
//            }
//            let suffix = key.suffix(from: key.startIndex + 1)
//            node.insert(key: suffix, value: value)
//        }
    }
    
    func contains(_ key: FloatVector) -> Bool {
        return contains(ArraySlice(key.components))
    }

    private func contains(_ key: ArraySlice<Float>) -> Bool {
        guard key.count > 0 else {
            return true
        }
        let prefix = key[key.startIndex]
        let binIndex = binIndex(for: prefix)
        guard let node = nodes[binIndex] else {
            return false
        }
        guard key.count > 1 else {
            return true
        }
        let suffix = key.suffix(from: key.startIndex + 1)
        return node.contains(suffix)
    }
    
    struct Match {
        var value: FloatVector
        var distance: Float
    }

    func nearest(_ query: FloatVector, distance: Float = 0.0, radius: Int = 0) -> Match? {
        nodeCountMetric = 0
        comparisonCountMetric = 0
        guard let bin = nearestNode(query.components) else {
            return nil
        }
        comparisonCountMetric += bin.values.count
        guard var bestMatch = bin.nearestValue(query) else {
            return nil
        }
        if bestMatch.distance <= distance {
            // Best match is already within the required threshold
            return bestMatch
        }
        
        var leftNode = bin
        var rightNode = bin
        for _ in 0 ..< radius {
            leftNode = leftNode.leftNode!
            rightNode = rightNode.rightNode!
            
            comparisonCountMetric += leftNode.values.count
            if let match = leftNode.nearestValue(query) {
                if match.distance <= distance {
                    return match
                }
            }
            
            comparisonCountMetric += rightNode.values.count
            if let match = rightNode.nearestValue(query) {
                if match.distance <= distance {
                    return match
                }
            }
        }
        
        return nil
    }
    
    func nearest(_ query: FloatVector, radius: Int = 0) -> Match? {
        nodeCountMetric = 0
        comparisonCountMetric = 0
        guard let bin = nearestNode(query.components) else {
            return nil
        }
        comparisonCountMetric += bin.values.count
        guard var bestMatch = bin.nearestValue(query) else {
            return nil
        }
        var node = bin
        for _ in 0 ..< radius {
            node = node.leftNode!
            comparisonCountMetric += node.values.count
            guard let match = node.nearestValue(query) else {
                continue
            }
            guard match.distance < bestMatch.distance else {
                continue
            }
            bestMatch = match
        }

        node = bin
        for _ in 0 ..< radius {
            node = node.rightNode!
            comparisonCountMetric += node.values.count
            guard let match = node.nearestValue(query) else {
                continue
            }
            guard match.distance < bestMatch.distance else {
                continue
            }
            bestMatch = match
        }

        return bestMatch
    }
    
    private func nearestNode(_ key: [Float]) -> Trie? {
        var current = self
        for i in 0 ..< key.count {
            nodeCountMetric += 1
            let value = key[i]
            let binIndex = current.binIndex(for: value)
            guard let node = current.closestNode(to: binIndex) else {
                return nil
            }
            current = node
        }
        return current
    }
    
    private func closestNode(to binIndex: Int) -> Trie? {
        if let node = nodes[binIndex] {
            return node
        }
        var bestDistance: Int = .max
        var bestNode: Trie?
        for j in 0 ..< numberOfBins {
            guard let node = nodes[j] else {
                continue
            }
            let distance = binDifference(binIndex, j)
            if distance < bestDistance {
                bestDistance = distance
                bestNode = node
            }
        }
        return bestNode
    }
    
    private func nearestValue(_ query: FloatVector) -> Match? {
        var bestDistance: Float = .greatestFiniteMagnitude
        var bestNeighbor: FloatVector?
        for value in values {
            let distance = query.distance(to: value)
            if distance < bestDistance {
                bestDistance = distance
                bestNeighbor = value
            }
        }
        guard let bestNeighbor else {
            return nil
        }
        return Match(
            value: bestNeighbor,
            distance: bestDistance
        )
    }

    private func binDifference(_ a: Int, _ b: Int) -> Int {
        precondition(a >= 0)
        precondition(a < numberOfBins)
        precondition(b >= 0)
        precondition(b < numberOfBins)
        return wrapBinIndex(abs(b - a))
    }
    
    private func binIndex(for value: Float) -> Int {
        precondition(value >= 0)
        precondition(value <= 1)
        let index = Int((value * Float(numberOfBins - 1)).rounded())
        precondition(index >= 0)
        precondition(index < numberOfBins)
        return index
    }
    
    private func binIndex(before index: Int) -> Int {
        precondition(index >= 0)
        precondition(index < numberOfBins)
        return wrapBinIndex(index - 1)
    }
    
    private func binIndex(after index: Int) -> Int {
        precondition(index >= 0)
        precondition(index < numberOfBins)
        return wrapBinIndex(index + 1)
    }
    
    private func wrapBinIndex(_ input: Int) -> Int {
        var output = input
        let n = numberOfBins - 1
        if output < 0 {
            output += n
        }
        else if output >= n {
            output -= n
        }
        precondition(output >= 0)
        precondition(output < numberOfBins)
        return output
    }
}

extension Trie: Equatable {
    
    static func ==(lhs: Trie, rhs: Trie) -> Bool {
        lhs.numberOfBins == rhs.numberOfBins &&
        lhs.nodes == rhs.nodes
    }
}
