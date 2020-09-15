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
import Logging

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Context Protocol

/// The `ContextProtocol` MAY be adopted by specific "framework contexts" such as e.g. `CoolFramework.Context` in
/// order to allow users to pass such context directly to libraries accepting any context.
///
/// This allows frameworks and library authors to offer APIs which compose more easily.
/// Please refer to the "Reference Implementation" notes on each of the requirements to know how to implement this protocol correctly.
public protocol Context {
    /// Get the `Baggage` container.
    var baggage: Baggage { get }

    /// The `Logger` associated with this context carrier.
    ///
    /// It automatically populates the loggers metadata based on the `BaggageContext` associated with this context object.
    ///
    /// ### Implementation note
    ///
    /// Libraries and/or frameworks which conform to this protocol with their "Framework Context" types,
    /// SHOULD implement this logger by wrapping the "raw" logger associated with  `_logger.with(self.baggage)` function,
    /// which efficiently handles the bridging of baggage to logging metadata values.
    ///
    /// ### Reference Implementation
    ///
    /// Writes to the `logger` metadata SHOULD NOT be reflected in the `baggage`,
    /// however writes to the underlying `baggage` SHOULD be reflected in the `logger`.
    ///
    ///     struct MyFrameworkContext: ContextProtocol {
    ///       var baggage: Baggage
    ///       private let _logger: Logger
    ///
    ///       var logger: Logger {
    ///         return self._logger.with(self.baggage)
    ///       }
    ///     }
    var logger: Logger { get }
}

/// A default `Context` type.
///
/// It is a carrier of contextual `Baggage` and related `Logger`, allowing to log and trace throughout a system.
///
/// Any values set on the `baggage` will be made accessible to the logger as call-site metadata, allowing it to log those.
///
/// ### Logged Metadata and Baggage Items
///
/// Please refer to your configured log handler documentation about how to configure which metadata values should be logged
/// and which not, as each log handler may handle and configure those differently. The default implementations log *all*
/// metadata/baggage values present, which often is the right thing, however in larger systems one may want to choose a
/// log handler which allows for configuring these details.
///
/// ### Accepting context types in APIs
///
/// It is preferred to accept values of `ContextProtocol` in library APIs, as this yields a more flexible API shape,
/// to which other libraries/frameworks may pass their specific context objects.
///
/// - SeeAlso: `Baggage` from the Baggage module.
/// - SeeAlso: `Logger` from the SwiftLog package.
public struct DefaultContext: Context {
    /// The `Baggage` carried with this context.
    /// It's values will automatically be made available to the `logger` as metadata when logging.
    ///
    /// Baggage values are different from plain logging metadata in that they are intended to be
    /// carried across process and node boundaries (serialized and deserialized) and are made
    /// available to instruments using `swift-distributed-tracing`.
    public var baggage: Baggage

    public var logger: Logger {
        get {
            return self._logger.with(self.baggage)
        }
        set {
            self._logger = newValue
        }
    }

    private var _logger: Logger

    public init(baggage: Baggage, logger underlying: Logger) {
        self.baggage = baggage
        self._logger = underlying
    }

    public init<C>(context: C) where C: Context {
        self._logger = context.logger
        self.baggage = context.baggage
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: `with...` functions

extension DefaultContext {
    /// Fluent API allowing for modification of underlying logger when passing the context to other functions.
    ///
    /// - Parameter logger: Logger that should replace the underlying logger of this context.
    /// - Returns: new context, with the passed in `logger`
    public func withLogger(_ function: (inout Logger) -> Void) -> DefaultContext {
        var logger = self._logger
        function(&logger)
        return .init(baggage: self.baggage, logger: logger)
    }

    /// Fluent API allowing for modification of underlying log level when passing the context to other functions.
    ///
    /// - Parameter logLevel: New log level which should be used to create the new context
    /// - Returns: new context, with the passed in `logLevel` used for the underlying logger
    public func withLogLevel(_ logLevel: Logger.Level) -> DefaultContext {
        var copy = self
        copy.logger.logLevel = logLevel
        return copy
    }

    /// Fluent API allowing for modification a few baggage values when passing the context to other functions, e.g.
    ///
    ///     makeRequest(url, context: context.withBaggage {
    ///         $0.traceID = "fake-value"
    ///         $0.calledFrom = #function
    ///     })
    ///
    /// - Parameter function:
    public func withBaggage(_ function: (inout Baggage) -> Void) -> DefaultContext {
        var baggage = self.baggage
        function(&baggage)
        return self.withBaggage(baggage)
    }

    /// Fluent API allowing for replacement of underlying baggage when passing the context to other functions.
    ///
    /// - Warning: Use with caution, generally it is not recommended to modify an entire baggage, but rather only add a few values to it.
    ///
    /// - Parameter baggage: baggage that should *replace* the context's current baggage.
    /// - Returns: new context, with the passed in baggage
    public func withBaggage(_ baggage: Baggage) -> DefaultContext {
        var copy = self
        copy.baggage = baggage
        return copy
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Context Initializers

extension DefaultContext {
    /// An empty baggage context intended as the "root" or "initial" baggage context background processing tasks, or as the "root" baggage context.
    ///
    /// It is never canceled, has no values, and has no deadline.
    /// It is typically used by the main function, initialization, and tests, and as the top-level Context for incoming requests.
    ///
    /// ### Usage in frameworks and libraries
    /// This function is really only intended to be used frameworks and libraries, at the "top-level" where a request's,
    /// message's or task's processing is initiated. For example, a framework handling requests, should create an empty
    /// context when handling a request only to immediately populate it with useful trace information extracted from e.g.
    /// request headers.
    ///
    /// ### Usage in applications
    /// Application code should never have to create an empty context during the processing lifetime of any request,
    /// and only should create contexts if some processing is performed in the background - thus the naming of this property.
    ///
    /// Usually, a framework such as an HTTP server or similar "request handler" would already provide users
    /// with a context to be passed along through subsequent calls.
    ///
    /// If unsure where to obtain a context from, prefer using `.TODO("Not sure where I should get a context from here?")`,
    /// such that other developers are informed that the lack of context was not done on purpose, but rather because either
    /// not being sure where to obtain a context from, or other framework limitations -- e.g. the outer framework not being
    /// context aware just yet.
    public static func background(logger: Logger) -> DefaultContext {
        return .init(baggage: .background, logger: logger)
    }
}

extension DefaultContext {
    /// A baggage context intended as a placeholder until a real value can be passed through a function call.
    ///
    /// It should ONLY be used while prototyping or when the passing of the proper context is not yet possible,
    /// e.g. because an external library did not pass it correctly and has to be fixed before the proper context
    /// can be obtained where the TO-DO is currently used.
    ///
    /// ## Crashing on TO-DO context creation
    /// You may set the `BAGGAGE_CRASH_TODOS` variable while compiling a project in order to make calls to this function crash
    /// with a fatal error, indicating where a to-do baggage context was used. This comes in handy when wanting to ensure that
    /// a project never ends up using with code initially was written as "was lazy, did not pass context", yet the
    /// project requires context passing to be done correctly throughout the application. Similar checks can be performed
    /// at compile time easily using linters (not yet implemented), since it is always valid enough to detect a to-do context
    /// being passed as illegal and warn or error when spotted.
    ///
    /// ## Example
    ///
    ///     frameworkHandler { what in
    ///         hello(who: "World", baggage: .TODO(logger: logger, "The framework XYZ should be modified to pass us a context here, and we'd pass it along"))
    ///     }
    ///
    /// - Parameters:
    ///   - reason: Informational reason for developers, why a placeholder context was used instead of a proper one,
    /// - Returns: Empty "to-do" baggage context which should be eventually replaced with a carried through one, or `background`.
    public static func TODO(logger: Logger, _ reason: StaticString? = "", function: String = #function, file: String = #file, line: UInt = #line) -> DefaultContext {
        let baggage = Baggage.TODO(reason, function: function, file: file, line: line)
        #if BAGGAGE_CRASH_TODOS
        fatalError("BAGGAGE_CRASH_TODOS: at \(file):\(line) (function \(function)), reason: \(reason)", file: file, line: line)
        #else
        return .init(baggage: baggage, logger: logger)
        #endif
    }
}
