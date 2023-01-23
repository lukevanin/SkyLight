//
//  KDTreeTests.swift
//  SkyLightTests
//
//  Created by Luke Van In on 2023/01/16.
//

import XCTest

@testable import SkyLight


final class KDTreeTests: XCTestCase {
    
    typealias Vector = FloatVector

    func testInit_withEmptyList_shouldCreateEmptyTree() {
        let subject = KDTree(nodes: [])
        XCTAssertNil(subject)
    }

    func testInit_withOneElement_shouldCreateTreeWithOneElement() {
        let expected = KDTree(
            id: 0,
            location: Vector([1, 0]),
            d: 0,
            leftChild: nil,
            rightChild: nil
        )
        let subject = KDTree(
            nodes: [
                KDTree.Node(
                    id: 0,
                    coordinate: Vector([1, 0])
                )
            ]
        )
        XCTAssertEqual(subject, expected)
    }

    func testInit_withTwoElements_shouldCreateTreeWithOneElementAndOneChildElement() {
        let expected = KDTree(
            id: 1,
            location: Vector([2, 0]),
            d: 0,
            leftChild: KDTree(
                id: 0,
                location: Vector([1, 0]),
                d: 1,
                leftChild: nil,
                rightChild: nil
            ),
            rightChild: nil
        )
        let subject = KDTree(
            nodes: [
                KDTree.Node(
                    id: 0,
                    coordinate: Vector([1, 0])
                ),
                KDTree.Node(
                    id: 1,
                    coordinate: Vector([2, 0])
                )
            ]
        )
        XCTAssertEqual(subject, expected)
    }

    func testInit_withThreeElements_shouldCreateTreeWithOneElementAndTwoChildElements() {
        let expected = KDTree(
            id: 1,
            location: Vector([2, 0]),
            d: 0,
            leftChild: KDTree(
                id: 0,
                location: Vector([1, 0]),
                d: 1,
                leftChild: nil,
                rightChild: nil
            ),
            rightChild: KDTree(
                id: 2,
                location: Vector([3, 0]),
                d: 1,
                leftChild: nil,
                rightChild: nil
            )
        )
        let subject = KDTree(
            nodes: [
                KDTree.Node(id: 0, coordinate: Vector([1, 0])),
                KDTree.Node(id: 1, coordinate: Vector([2, 0])),
                KDTree.Node(id: 2, coordinate: Vector([3, 0]))
            ]
        )
        XCTAssertEqual(subject, expected)
    }

    func testInit_withThreeElementsAndTwoEqualElements_shouldCreateTreeWithOneElementAndTwoChildElements() {
        let expected = KDTree(
            id: 1,
            location: Vector([1, 0]),
            d: 0,
            leftChild: KDTree(
                id: 0,
                location: Vector([1, 0]),
                d: 1,
                leftChild: nil,
                rightChild: nil
            ),
            rightChild: KDTree(
                id: 2,
                location: Vector([2, 0]),
                d: 1,
                leftChild: nil,
                rightChild: nil
            )
        )
        let subject = KDTree(
            nodes: [
                KDTree.Node(
                    id: 0,
                    coordinate: Vector([1, 0])
                ),
                KDTree.Node(
                    id: 1,
                    coordinate: Vector([1, 0])
                ),
                KDTree.Node(
                    id: 2,
                    coordinate: Vector([2, 0])
                )
            ]
        )
        XCTAssertEqual(subject, expected)
    }

    func testInit_withThreeUnorderedElements_shouldCreateTreeWithOneElementAndTwoChildElements() {
        let expected = KDTree(
            id: 1,
            location: Vector([2, 0]),
            d: 0,
            leftChild: KDTree(
                id: 2,
                location: Vector([1, 0]),
                d: 1,
                leftChild: nil,
                rightChild: nil
            ),
            rightChild: KDTree(
                id: 0,
                location: Vector([3, 0]),
                d: 1,
                leftChild: nil,
                rightChild: nil
            )
        )
        let subject = KDTree(
            nodes: [
                KDTree.Node(id: 0, coordinate: Vector([3, 0])),
                KDTree.Node(id: 1, coordinate: Vector([2, 0])),
                KDTree.Node(id: 2, coordinate: Vector([1, 0]))
            ]
        )
        XCTAssertEqual(subject, expected)
    }
    
    func testInit_withFourElements() {
        let expected = KDTree(
            id: 2,
            location: Vector([3, 0]),
            d: 0,
            leftChild: KDTree(
                id: 1,
                location: Vector([1, 2]),
                d: 1,
                leftChild: KDTree(
                    id: 0,
                    location: Vector([1, 1]),
                    d: 2,
                    leftChild: nil,
                    rightChild: nil
                ),
                rightChild: nil
            ),
            rightChild: KDTree(
                id: 3,
                location: Vector([4, 0]),
                d: 1,
                leftChild: nil,
                rightChild: nil
            )
        )
        let subject = KDTree(
            nodes: [
                KDTree.Node(id: 0, coordinate: Vector([1, 1])),
                KDTree.Node(id: 1, coordinate: Vector([1, 2])),
                KDTree.Node(id: 2, coordinate: Vector([3, 0])),
                KDTree.Node(id: 3, coordinate: Vector([4, 0]))
            ]
        )
        XCTAssertEqual(subject, expected)
    }
    
    func testInit_withKnownInputs_shouldReturnKnownStructure() {
        let node0 = KDTree(
            id: 0,
            location: Vector([30, 40])
        )
        let node1 = KDTree(
            id: 1,
            location: Vector([5, 25])
        )
        let node2 = KDTree(
            id: 2,
            location: Vector([10, 12])
        )
        let node3 = KDTree(
            id: 3,
            location: Vector([70, 70])
        )
        let node4 = KDTree(
            id: 4,
            location: Vector([50, 30])
        )
        let node5 = KDTree(
            id: 5,
            location: Vector([35, 45])
        )
        let expected = node5
        node5.leftChild = node1
        node5.rightChild = node3
        node1.leftChild = node2
        node1.rightChild = node0
        node3.leftChild = node4
        let subject = KDTree(
            nodes: [
                KDTree.Node(id: 0, coordinate: Vector([30, 40])),
                KDTree.Node(id: 1, coordinate: Vector([5, 25])),
                KDTree.Node(id: 2, coordinate: Vector([10, 12])),
                KDTree.Node(id: 3, coordinate: Vector([70, 70])),
                KDTree.Node(id: 4, coordinate: Vector([50, 30])),
                KDTree.Node(id: 5, coordinate: Vector([35, 45])),
            ]
        )
        XCTAssertEqual(subject, expected)
    }
    
    func testFind_withMatchingCoordinate_shouldReturnNode() {
        let subject = KDTree(
            nodes: [
                KDTree.Node(id: 0, coordinate: Vector([30, 40])),
                KDTree.Node(id: 1, coordinate: Vector([5, 25])),
                KDTree.Node(id: 2, coordinate: Vector([10, 12])),
                KDTree.Node(id: 3, coordinate: Vector([70, 70])),
                KDTree.Node(id: 4, coordinate: Vector([50, 30])),
                KDTree.Node(id: 5, coordinate: Vector([35, 45])),
            ]
        )
        let result = subject?.findExact(query: Vector([50, 30]))
        let expected = KDTree.Node(id: 4, coordinate: Vector([50, 30]))
        XCTAssertEqual(result, expected)
    }
    
    func testFind_withNoMatchingCoordinate_shouldReturnNil() {
        let subject = KDTree(
            nodes: [
                KDTree.Node(id: 0, coordinate: Vector([1, 1])),
                KDTree.Node(id: 1, coordinate: Vector([1, 2])),
                KDTree.Node(id: 2, coordinate: Vector([3, 5])),
                KDTree.Node(id: 3, coordinate: Vector([1, 7]))
            ]
        )
        let result = subject?.findExact(query: Vector([4, 5]))
        XCTAssertNil(result)
    }
    
    func testNearest_withExactMatch_shouldReturnNode() {
        let subject = KDTree(
            nodes: [
                KDTree.Node(id: 0, coordinate: Vector([1, 1])),
                KDTree.Node(id: 1, coordinate: Vector([2, 2])),
                KDTree.Node(id: 2, coordinate: Vector([3, 3])),
                KDTree.Node(id: 3, coordinate: Vector([4, 4]))
            ]
        )
        let expected = KDTree.Match(
            id: 1,
            coordinate: Vector([2, 2]),
            distance: 0
        )
        let result = subject?.findNearest(query: Vector([2, 2]))
        XCTAssertEqual(result, expected)
    }
    
    func testNearest_withInexactMatch_shouldReturnNearestNode() {
        let scenarios = [
            (
                query: Vector([4, 5]),
                result: KDTree.Match(
                    id: 0,
                    coordinate: Vector([1, 1]),
                    distance: 5 // sqrt(3 * 3 + 4 * 4) = sqrt(25)
                )
            ),
            (
                query: Vector([-2, -3]),
                result: KDTree.Match(
                    id: 0,
                    coordinate: Vector([1, 1]),
                    distance: 5
                )
            ),
            (
                query: Vector([60, 70]),
                result: KDTree.Match(
                    id: 3,
                    coordinate: Vector([30, 30]),
                    distance: 50 // sqrt(30 * 30 + 40 * 40) = sqrt(50)
                )
            ),
        ]
        let subject = KDTree(
            nodes: [
                KDTree.Node(id: 0, coordinate: Vector([1, 1])),
                KDTree.Node(id: 1, coordinate: Vector([10, 10])),
                KDTree.Node(id: 2, coordinate: Vector([20, 20])),
                KDTree.Node(id: 3, coordinate: Vector([30, 30]))
            ]
        )
        for scenario in scenarios {
            let result = subject?.findNearest(query: scenario.query)
            XCTAssertEqual(result, scenario.result)
        }
    }
    
    func testApproximateNearest_withInexactMatch_shouldReturnBestNearest() {
        let scenarios = [
            (
                query: Vector([4, 5]),
                result: KDTree.Match(
                    id: 0,
                    coordinate: Vector([1, 1]),
                    distance: 5 // sqrt(3 * 3 + 4 * 4) = sqrt(25)
                )
            ),
            (
                query: Vector([-2, -3]),
                result: KDTree.Match(
                    id: 0,
                    coordinate: Vector([1, 1]),
                    distance: 5
                )
            ),
            (
                query: Vector([60, 70]),
                result: KDTree.Match(
                    id: 3,
                    coordinate: Vector([30, 30]),
                    distance: 50 // sqrt(30 * 30 + 40 * 40) = sqrt(50)
                )
            ),
        ]
        let subject = KDTree(
            nodes: [
                KDTree.Node(id: 0, coordinate: Vector([1, 1])),
                KDTree.Node(id: 1, coordinate: Vector([10, 10])),
                KDTree.Node(id: 2, coordinate: Vector([20, 20])),
                KDTree.Node(id: 3, coordinate: Vector([30, 30]))
            ]
        )
        for scenario in scenarios {
            let result = subject!.findApproximateNearest(query: scenario.query)
            XCTAssertEqual(result, scenario.result)
        }
    }
    
    func testApproximateNearest_withLargeDataset() {
        struct Neighbor: CustomStringConvertible {
            let id: Int
            let distance: Float
            
            var description: String {
                "<Neighbor #\(id) @\(String(format: "%0.3f", distance))>"
            }
        }
        
        let n = 1000
        let m = 1000
        let d = 10
        var nodes: [KDTree.Node] = []
        var queries: [Vector] = []
        var nearestNeighbors: [Neighbor] = []
        
        // Generate sample data
        for i in 0 ..< n {
            var vector: [Float] = Array(repeating: 0, count: d)
            for j in 0 ..< d {
                vector[j] = .random(in: 0...1)
            }
            let node = KDTree.Node(id: i, coordinate: Vector(vector))
            nodes.append(node)
        }
//        print("nodes", nodes)
        
        // Generate queries.
        for _ in 0 ..< m {
            var vector: [Float] = Array(repeating: 0, count: d)
            for j in 0 ..< d {
                vector[j] = .random(in: 0...1)
            }
            queries.append(Vector(vector))
        }

        // Compute actual nearest neighbor for each node using brute force.
        for i in 0 ..< m {
            let query = queries[i]
            var nearestDistance: Float = .greatestFiniteMagnitude
            var nearestNeighbor: Neighbor!
            for j in 0 ..< n {
                let currentNode = nodes[j]
                let distance = currentNode.coordinate.distance(to: query)
                guard distance < nearestDistance else {
                    continue
                }
                nearestDistance = distance
                nearestNeighbor = Neighbor(id: j, distance: distance)
            }
            nearestNeighbors.append(nearestNeighbor)
        }
//        print("nearest neighbors", nearestNeighbors)
        
        // Compute approximate nearest neighbor.
        var totalError: Float = 0
        var totalCorrect: Int = 0
        var totalQueries: Int = 0
        var totalNodes: Int = 0
        let subject = KDTree(nodes: nodes)!
//        measure {
            for i in 0 ..< m {
//        let i = 0
                let query = queries[i]
                let foundNeighbor = subject.findApproximateNearest(query: query)
//                let foundNeighbor = subject.findNearest(query: query)
                totalNodes += subject.searchCountMetric
                let foundDistance = foundNeighbor.coordinate.distance(to: query)
                let exactNeighbor = nearestNeighbors[i]
                let exactDistance = exactNeighbor.distance
                let delta = exactDistance - foundDistance
                let error = delta * delta
                totalError += error
                let correct = error == 0
                totalCorrect += correct ? 1 : 0
                totalQueries += 1
                //            var symbol: String = correct ? "✅" : "❌"
                //            print(
                //                "#\(i)",
                //                symbol,
                //                "found=\(String(format: "%0.3f", foundDistance))",
                //                "exact=\(String(format: "%0.3f", exactDistance))",
                //                "error=\(String(format: "%0.3f", error))"
                //            )
            }
//        }
        let meanSquaredError = totalError / Float(totalQueries)
        let percentCorrect = Float(totalCorrect) / Float(totalQueries)
        let averageNodesPerQuery = Float(totalNodes) / Float(totalQueries)
        print("Total queries: \(totalQueries)")
        print("Mean squared error: \(String(format: "%0.3f", meanSquaredError))")
        print("Correct: \(totalCorrect) out of \(totalQueries) = \(String(format: "%0.3f", percentCorrect))")
        print("Total nodes: \(totalNodes)")
        print("Average nodes per query: \(String(format: "%0.3f", averageNodesPerQuery))")
    }

}
