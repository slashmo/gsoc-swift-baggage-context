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

@testable import Baggage
import XCTest

final class FrameworkBaggageContextTests: XCTestCase {
    func testBaggageContextSubscript() {
        var carrier = TestFrameworkContext()

        // mutate baggage context through carrier
        carrier[TestKey.self] = 42
        XCTAssertEqual(carrier[TestKey.self], 42)
        XCTAssertEqual(carrier.baggage[TestKey.self], 42)

        // mutate baggage context directly
        carrier.baggage[OtherKey.self] = "test"
        XCTAssertEqual(carrier.baggage[OtherKey.self], "test")
        XCTAssertEqual(carrier[OtherKey.self], "test")
    }

    func testBaggageContextForEach() {
        var contents = [AnyBaggageKey: Any]()
        var carrier = TestFrameworkContext()

        carrier[TestKey.self] = 42
        carrier[OtherKey.self] = "test"

        carrier.forEachBaggageItem { key, value in
            contents[key] = value
        }

        XCTAssertNotNil(contents[AnyBaggageKey(TestKey.self)])
        XCTAssertEqual(contents[AnyBaggageKey(TestKey.self)] as? Int, 42)
        XCTAssertNotNil(contents[AnyBaggageKey(OtherKey.self)])
        XCTAssertEqual(contents[AnyBaggageKey(OtherKey.self)] as? String, "test")
    }
}

private struct TestFrameworkContext: BaggageProtocol {
    var baggage = Baggage()

    subscript<Key: BaggageKey>(_ key: Key.Type) -> Key.Value? {
        get {
            return self.baggage[key]
        }
        set {
            self.baggage[key] = newValue
        }
    }

    func forEachBaggageItem(_ body: (AnyBaggageKey, Any) throws -> Void) rethrows {
        return try self.baggage.forEachBaggageItem(body)
    }
}

private enum TestKey: Baggage.Key {
    typealias Value = Int
}

private enum OtherKey: Baggage.Key {
    typealias Value = String
}
