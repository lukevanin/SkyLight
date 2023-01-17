//
//  KDTreeTests.swift
//  SkySightTests
//
//  Created by Luke Van In on 2023/01/16.
//

import XCTest

@testable import SkySight

final class KDTreeTests: XCTestCase {

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
        let result = subject?.find(query: Vector([50, 30]))
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
        let result = subject?.find(query: Vector([4, 5]))
        XCTAssertNil(result)
    }
}
