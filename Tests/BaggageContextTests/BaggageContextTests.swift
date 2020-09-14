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
import BaggageContext
import Logging
import XCTest

final class BaggageContextTests: XCTestCase {
    func test_ExampleFrameworkContext_dumpBaggage() throws {
        var baggage = Baggage.background
        let logger = Logger(label: "TheLogger")

        baggage.testID = 42
        let context = ExampleFrameworkContext(context: baggage, logger: logger)

        func frameworkFunctionDumpsBaggage(param: String, context: ContextProtocol) -> String {
            var s = ""
            context.baggage.forEachBaggageItem { key, item in
                s += "\(key.name): \(item)\n"
            }
            return s
        }

        let result = frameworkFunctionDumpsBaggage(param: "x", context: context)
        XCTAssertEqual(
            result,
            """
            TestIDKey: 42

            """
        )
    }

    func test_ExampleMutableFrameworkContext_dumpBaggage() throws {
        let baggage = Baggage.background
        let logger = Logger(label: "TheLogger")

        var context: ContextProtocol & BaggageProtocol = ExampleMutableFrameworkContext(context: baggage, logger: logger)
        context.testID = 42

        func frameworkFunctionDumpsBaggage(param: String, context: ContextProtocol & BaggageProtocol) -> String {
            var s = ""
            context.forEachBaggageItem { key, item in
                s += "\(key.name): \(item)\n"
            }
            return s
        }

        let result = frameworkFunctionDumpsBaggage(param: "x", context: context)
        XCTAssertEqual(
            result,
            """
            TestIDKey: 42

            """
        )
    }

    func test_ExampleMutableFrameworkContext_log_withBaggage() throws {
        let baggage = Baggage.background
        let logging = TestLogging()
        let logger = Logger(label: "TheLogger", factory: { label in logging.make(label: label) })

        var context = ExampleMutableFrameworkContext(context: baggage, logger: logger)

        context.secondTestID = "value"
        context.testID = 42
        context.logger.info("Hello")

        context.testID = nil
        context.logger.warning("World")

        logging.history.assertExist(level: .info, message: "Hello", metadata: [
            "TestIDKey": .stringConvertible(42),
            "secondIDExplicitlyNamed": "value",
        ])
        logging.history.assertExist(level: .warning, message: "World", metadata: [
            "secondIDExplicitlyNamed": "value",
        ])
    }

    func test_ExampleMutableFrameworkContext_log_prefersBaggageContextOverExistingLoggerMetadata() {
        let baggage = Baggage.background
        let logging = TestLogging()
        var logger = Logger(label: "TheLogger", factory: { label in logging.make(label: label) })
        logger[metadataKey: "secondIDExplicitlyNamed"] = "set on logger"

        var context = ExampleMutableFrameworkContext(context: baggage, logger: logger)

        context.secondTestID = "set on baggage"

        context.logger.info("Hello")

        logging.history.assertExist(level: .info, message: "Hello", metadata: [
            "secondIDExplicitlyNamed": "set on baggage",
        ])
    }
}

struct ExampleFrameworkContext: BaggageContext.ContextProtocol {
    let baggage: Baggage
    let logger: Logger

    init(context baggage: Baggage, logger: Logger) {
        self.baggage = baggage
        self.logger = logger.with(self.baggage)
    }

    var asBaggageContext: Context {
        return .init(baggage: self.baggage, logger: self.logger)
    }
}

struct ExampleMutableFrameworkContext: ContextProtocol, BaggageProtocol {
    var baggage: Baggage

    private var _logger: Logger
    var logger: Logger {
        return self._logger.with(self.baggage)
    }

    init(context baggage: Baggage, logger: Logger) {
        self.baggage = baggage
        self._logger = logger
    }

    subscript<Key: BaggageKey>(key: Key.Type) -> Key.Value? {
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

    var asBaggageContext: Context {
        return .init(baggage: self.baggage, logger: self._logger)
    }
}

struct CoolFrameworkContext: BaggageContext.ContextProtocol {
    private var _logger: Logger = Logger(label: "some frameworks logger")
    var logger: Logger {
        return self._logger.with(self.baggage)
    }

    var baggage: Baggage = .background

    // framework context defines other values as well
    let frameworkField: String = ""

    // including the popular eventLoop
    let eventLoop: FakeEventLoop

    subscript<Key: BaggageKey>(key: Key.Type) -> Key.Value? {
        return self.baggage[key]
    }

    func forEachBaggageItem(_ body: (AnyBaggageKey, Any) throws -> Void) rethrows {
        return try self.baggage.forEachBaggageItem(body)
    }

    var asBaggageContext: Context {
        return .init(baggage: self.baggage, logger: self._logger)
    }
}

struct FakeEventLoop {}

private extension BaggageProtocol {
    var testID: Int? {
        get {
            return self[TestIDKey.self]
        }
        set {
            self[TestIDKey.self] = newValue
        }
    }

    var secondTestID: String? {
        get {
            return self[SecondTestIDKey.self]
        }
        set {
            self[SecondTestIDKey.self] = newValue
        }
    }
}

private enum TestIDKey: Baggage.Key {
    typealias Value = Int
}

private enum SecondTestIDKey: Baggage.Key {
    typealias Value = String

    static let name: String? = "secondIDExplicitlyNamed"
}
