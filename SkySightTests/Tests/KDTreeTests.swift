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
        let subject = KDTree(elements: [], k: 2)
        XCTAssertNil(subject)
    }

    func testInit_withOneElement_shouldCreateTreeWithOneElement() {
        let expected = KDTree(
            location: [1, 0],
            leftChild: nil,
            rightChild: nil,
            k: 2,
            d: 0
        )
        let subject = KDTree(
            elements: [[1, 0]],
            k: 2
        )
        XCTAssertEqual(subject, expected)
    }

    func testInit_withTwoElements_shouldCreateTreeWithOneElementAndOneChildElement() {
        let expected = KDTree(
            location: [2, 0],
            leftChild: KDTree(
                location: [1, 0],
                leftChild: nil,
                rightChild: nil,
                k: 2,
                d: 1
            ),
            rightChild: nil,
            k: 2,
            d: 0
        )
        let subject = KDTree(
            elements: [[1, 0], [2, 0]],
            k: 2
        )
        XCTAssertEqual(subject, expected)
    }

    func testInit_withThreeElements_shouldCreateTreeWithOneElementAndTwoChildElements() {
        let expected = KDTree(
            location: [2, 0],
            leftChild: KDTree(
                location: [1, 0],
                leftChild: nil,
                rightChild: nil,
                k: 2,
                d: 1
            ),
            rightChild: KDTree(
                location: [3, 0],
                leftChild: nil,
                rightChild: nil,
                k: 2,
                d: 1
            ),
            k: 2,
            d: 0
        )
        let subject = KDTree(
            elements: [[1, 0], [2, 0], [3, 0]],
            k: 2
        )
        XCTAssertEqual(subject, expected)
    }

    func testInit_withThreeElementsAndTwoEqualElements_shouldCreateTreeWithOneElementAndTwoChildElements() {
        let expected = KDTree(
            location: [1, 0],
            leftChild: KDTree(
                location: [1, 0],
                leftChild: nil,
                rightChild: nil,
                k: 2,
                d: 1
            ),
            rightChild: KDTree(
                location: [2, 0],
                leftChild: nil,
                rightChild: nil,
                k: 2,
                d: 1
            ),
            k: 2,
            d: 0
        )
        let subject = KDTree(
            elements: [[1, 0], [1, 0], [2, 0]],
            k: 2
        )
        XCTAssertEqual(subject, expected)
    }

    func testInit_withThreeUnorderedElements_shouldCreateTreeWithOneElementAndTwoChildElements() {
        let expected = KDTree(
            location: [2, 0],
            leftChild: KDTree(
                location: [1, 0],
                leftChild: nil,
                rightChild: nil,
                k: 2,
                d: 1
            ),
            rightChild: KDTree(
                location: [3, 0],
                leftChild: nil,
                rightChild: nil,
                k: 2,
                d: 1
            ),
            k: 2,
            d: 0
        )
        let subject = KDTree(
            elements: [[3, 0], [2, 0], [1, 0]],
            k: 2
        )
        XCTAssertEqual(subject, expected)
    }
    
    func testInit_withFourElements() {
        let expected = KDTree(
            location: [3, 0],
            leftChild: KDTree(
                location: [1, 2],
                leftChild: KDTree(
                    location: [1, 1],
                    leftChild: nil,
                    rightChild: nil,
                    k: 2,
                    d: 2
                ),
                rightChild: nil,
                k: 2,
                d: 1
            ),
            rightChild: KDTree(
                location: [4, 0],
                leftChild: nil,
                rightChild: nil,
                k: 2,
                d: 1
            ),
            k: 2,
            d: 0
        )
        let subject = KDTree(
            elements: [[1, 1], [1, 2], [3, 0], [4, 0]],
            k: 2
        )
        XCTAssertEqual(subject, expected)
    }
}
