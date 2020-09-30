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
import BaggageContext
import Logging
import XCTest

final class FrameworkBaggageContextTests: XCTestCase {
    func testBaggageContextSubscript() {
        var context = TestFrameworkContext()

        // mutate baggage context directly
        context.baggage[OtherKey.self] = "test"
        XCTAssertEqual(context.baggage.otherKey, "test")
    }

    func testBaggageContextForEach() {
        var contents = [AnyBaggageKey: Any]()
        var context = TestFrameworkContext()

        context.baggage.testKey = 42
        context.baggage.otherKey = "test"

        context.baggage.forEach { key, value in
            contents[key] = value
        }

        XCTAssertNotNil(contents[AnyBaggageKey(TestKey.self)])
        XCTAssertEqual(contents[AnyBaggageKey(TestKey.self)] as? Int, 42)
        XCTAssertNotNil(contents[AnyBaggageKey(OtherKey.self)])
        XCTAssertEqual(contents[AnyBaggageKey(OtherKey.self)] as? String, "test")
    }
}

private struct TestFrameworkContext: Context {
    var baggage = Baggage.topLevel

    private var _logger = Logger(label: "test")
    var logger: Logger {
        get {
            return self._logger.with(self.baggage)
        }
        set {
            self._logger = newValue
        }
    }
}

private enum TestKey: Baggage.Key {
    typealias Value = Int
}

extension Baggage {
    var testKey: Int? {
        get {
            return self[TestKey.self]
        }
        set {
            self[TestKey.self] = newValue
        }
    }
}

private enum OtherKey: Baggage.Key {
    typealias Value = String
}

extension Baggage {
    var otherKey: String? {
        get {
            return self[OtherKey.self]
        }
        set {
            self[OtherKey.self] = newValue
        }
    }
}
