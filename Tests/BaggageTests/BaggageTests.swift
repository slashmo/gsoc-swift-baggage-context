//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Baggage Context open source project
//
// Copyright (c) 2020 Moritz Lang and the Swift Baggage Context project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Baggage
import XCTest

final class BaggageTests: XCTestCase {
    func testSubscriptAccess() {
        let testID = 42

        var baggage = Baggage.topLevel
        XCTAssertNil(baggage[_key: TestIDKey.self])

        baggage[_key: TestIDKey.self] = testID
        XCTAssertEqual(baggage[_key: TestIDKey.self], testID)

        baggage[_key: TestIDKey.self] = nil
        XCTAssertNil(baggage[_key: TestIDKey.self])
    }

    func testRecommendedConvenienceExtension() {
        let testID = 42

        var baggage = Baggage.topLevel
        XCTAssertNil(baggage.testID)

        baggage.testID = testID
        XCTAssertEqual(baggage.testID, testID)

        baggage[_key: TestIDKey.self] = nil
        XCTAssertNil(baggage.testID)
    }

    func testEmptyBaggageDescription() {
        XCTAssertEqual(String(describing: Baggage.topLevel), "Baggage(keys: [])")
    }

    func testSingleKeyBaggageDescription() {
        var baggage = Baggage.topLevel
        baggage.testID = 42

        XCTAssertEqual(String(describing: baggage), #"Baggage(keys: ["TestIDKey"])"#)
    }

    func testMultiKeysBaggageDescription() {
        var baggage = Baggage.topLevel
        baggage.testID = 42
        baggage[_key: SecondTestIDKey.self] = "test"

        let description = String(describing: baggage)
        XCTAssert(description.starts(with: "Baggage(keys: ["), "Was: \(description)")
        // use contains instead of `XCTAssertEqual` because the order is non-predictable (Dictionary)
        XCTAssert(description.contains("TestIDKey"), "Was: \(description)")
        XCTAssert(description.contains("ExplicitKeyName"), "Was: \(description)")
    }

    // ==== ------------------------------------------------------------------------------------------------------------
    // MARK: Factories

    func test_todo_context() {
        // the to-do context can be used to record intentions for why a context could not be passed through
        let context = Baggage.TODO("#1245 Some other library should be adjusted to pass us context")
        _ = context // avoid "not used" warning

        // TODO: Can't work with protocols; re-consider the entire carrier approach... Context being a Baggage + Logger, and a specific type.
//        func take(context: BaggageContextProtocol) {
//            _ = context // ignore
//        }
//        take(context: .TODO("pass from request instead"))
    }

    func test_todo_empty() {
        let context = Baggage.topLevel
        _ = context // avoid "not used" warning

        // TODO: Can't work with protocols; re-consider the entire carrier approach... Context being a Baggage + Logger, and a specific type.
        // static member 'empty' cannot be used on protocol metatype 'BaggageContextProtocol.Protocol'
//        func take(context: BaggageContextProtocol) {
//            _ = context // ignore
//        }
//        take(context: .topLevel)
    }
}

private enum TestIDKey: Baggage.Key {
    typealias Value = Int
}

private extension Baggage {
    var testID: Int? {
        get {
            return self[_key: TestIDKey.self]
        }
        set {
            self[_key: TestIDKey.self] = newValue
        }
    }
}

private enum SecondTestIDKey: Baggage.Key {
    typealias Value = String

    static let name: String? = "ExplicitKeyName"
}
