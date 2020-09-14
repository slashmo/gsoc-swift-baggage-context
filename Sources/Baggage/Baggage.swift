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

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Baggage

/// A `Baggage` is a heterogeneous storage type with value semantics for keyed values in a type-safe
/// fashion.
///
/// Its values are uniquely identified via `BaggageKey`s (by type identity). These keys also dictate the type of
/// value allowed for a specific key-value pair through their associated type `Value`.
///
/// ## Defining keys and accessing values
/// Baggage keys are defined as types, most commonly case-less enums (as no actual instances are actually required)
/// which conform to the `Baggage.Key` protocol:
///
///     private enum TestIDKey: BaggageKey {
///       typealias Value = String
///     }
///
/// While defining a key, one should also immediately declare an extension on `BaggageProtocol`,
/// to allow convenient and discoverable ways to interact with the baggage item, the extension should take the form of:
///
///     extension BaggageProtocol {
///       var testID: TestIDKey.Value? {
///         get {
///           self[TestIDKey.self]
///         } set {
///           self[TestIDKey.self] = newValue
///         }
///       }
///     }
///
/// For consistency, it is recommended to name key types with the `...Key` suffix (e.g. `SomethingKey`) and the property
/// used to access a value identifier by such key the prefix of the key (e.g. `something`). Please also observe the usual
/// Swift naming conventions, e.g. prefer `ID` to `Id` etc.
///
/// ## Usage
/// Using a baggage container is fairly straight forward, as it boils down to using the prepared computed properties:
///
///     var context = Baggage.background
///     // set a new value
///     context.testID = "abc"
///     // retrieve a stored value
///     let testID = context.testID ?? "default"
///     // remove a stored value
///     context[TestIDKey.self] = nil
///
/// Note that normally a baggage should not be "created" ad-hoc by user code, but rather it should be passed to it from
/// a runtime. For example, when working in an HTTP server framework, it is most likely that the baggage is already passed
/// directly or indirectly (e.g. in a `BaggageContext` or `FrameworkContext`)
///
/// ### Accessing all values
///
/// The only way to access "all" values in a baggage context is by using the `forEachBaggageItem` function.
/// The baggage container on purpose does not expose more functions to prevent abuse and treating it as too much of an
/// arbitrary value smuggling container, but only make it convenient for tracing and instrumentation systems which need
/// to access either specific or all items carried inside a baggage.
public struct Baggage: BaggageProtocol {
    public typealias Key = BaggageKey

    private var _storage = [AnyBaggageKey: Any]()

    /// Internal on purpose, please use `Baggage.TODO` or `Baggage.background` to create an "empty" context,
    /// which carries more meaning to other developers why an empty context was used.
    init() {}

    public var baggage: Baggage {
        get {
            return self
        }
        set {
            self = newValue
        }
    }
}

extension Baggage {
    /// Creates a new empty baggage, generally used for background processing tasks or an "initial" baggage to be immediately
    /// populated with some values by a framework or runtime.
    ///
    /// Typically, this would only be called in a "top" or "background" setting, such as the main function, initialization,
    /// tests, beginning of some background task or some other top-level baggage to be immediately populated with incoming request/message information.
    ///
    /// ## Usage in frameworks and libraries
    /// This function is really only intended to be used frameworks and libraries, at the "top-level" where a request's,
    /// message's or task's processing is initiated. For example, a framework handling requests, should create an empty
    /// context when handling a request only to immediately populate it with useful trace information extracted from e.g.
    /// request headers.
    ///
    /// ## Usage in applications
    /// Application code should never have to create an empty context during the processing lifetime of any request,
    /// and only should create contexts if some processing is performed in the background - thus the naming of this property.
    ///
    /// Usually, a framework such as an HTTP server or similar "request handler" would already provide users
    /// with a context to be passed along through subsequent calls.
    ///
    /// If unsure where to obtain a context from, prefer using `.TODO("Not sure where I should get a context from here?")`,
    /// in order to inform other developers that the lack of context passing was not done on purpose, but rather because either
    /// not being sure where to obtain a context from, or other framework limitations -- e.g. the outer framework not being
    /// baggage context aware just yet.
    public static var background: Baggage {
        return Baggage()
    }
}

extension Baggage {
    /// A baggage intended as a placeholder until a real value can be passed through a function call.
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
    ///         hello(who: "World", baggage: .TODO("The framework XYZ should be modified to pass us a context here, and we'd pass it along"))
    ///     }
    ///
    /// - Parameters:
    ///   - reason: Informational reason for developers, why a placeholder context was used instead of a proper one,
    /// - Returns: Empty "to-do" baggage context which should be eventually replaced with a carried through one, or `background`.
    public static func TODO(_ reason: StaticString? = "", function: String = #function, file: String = #file, line: UInt = #line) -> Baggage {
        var context = Baggage.background
        #if BAGGAGE_CRASH_TODOS
        fatalError("BAGGAGE_CRASH_TODOS: at \(file):\(line) (function \(function)), reason: \(reason)")
        #else
        context[TODOKey.self] = .init(file: file, line: line)
        return context
        #endif
    }

    private enum TODOKey: BaggageKey {
        typealias Value = TODOLocation
        static var name: String? {
            return "todo"
        }
    }
}

/// The `BaggageProtocol` should not directly be used in APIs.
///
/// Prefer accepting the `ContextProtocol` in APIs which need to accept a baggage context.
/// If `Context` can not be used for some reason, it is preferable to accept a `Baggage` directly rather than this protocol.
public protocol BaggageProtocol {
    /// Get the `Baggage` container.
    var baggage: Baggage { get set }

    /// Provides type-safe access to the baggage's values.
    ///
    /// Rather than using this subscript directly, users SHOULD offer a convenience accessor to their values,
    /// using the following pattern:
    ///
    ///     extension BaggageProtocol {
    ///       var testID: TestIDKey.Value? {
    ///         get {
    ///           self[TestIDKey.self]
    ///         }
    ///         set {
    ///           self[TestIDKey.self] = newValue
    ///         }
    ///       }
    ///     }
    ///
    /// Note that specific baggage and context types MAY (and usually do), offer also a way to set baggage values,
    /// however in the most general case it is not required, as some frameworks may only be able to offer reading.
    subscript<Key: BaggageKey>(_ key: Key.Type) -> Key.Value? { get set }

    /// Calls the given closure for each item contained in the underlying `Baggage`.
    ///
    /// Order of those invocations is NOT guaranteed and should not be relied on.
    ///
    /// - Parameter body: A closure invoked with the type erased key and value stored for the key in this baggage.
    func forEachBaggageItem(_ body: (AnyBaggageKey, Any) throws -> Void) rethrows
}

/// Writable `BaggageProtocol`.
///
/// - SeeAlso: `_WritableBaggageProtocol`
public protocol _WritableBaggageProtocol: BaggageProtocol {
    var baggage: Baggage { get set }
}

extension Baggage {
    public subscript<Key: BaggageKey>(_ key: Key.Type) -> Key.Value? {
        get {
            guard let value = self._storage[AnyBaggageKey(key)] else { return nil }
            // safe to force-cast as this subscript is the only way to set a value.
            return (value as! Key.Value)
        }
        set {
            self._storage[AnyBaggageKey(key)] = newValue
        }
    }

    public func forEachBaggageItem(_ body: (AnyBaggageKey, Any) throws -> Void) rethrows {
        try self._storage.forEach { key, value in
            try body(key, value)
        }
    }
}

extension Baggage: CustomStringConvertible {
    /// A context's description prints only keys of the contained values.
    /// This is in order to prevent spilling a lot of detailed information of carried values accidentally.
    ///
    /// `Baggage`s are not intended to be printed "raw" but rather inter-operate with tracing, logging and other systems,
    /// which can use the `forEach` function providing access to its underlying values.
    public var description: String {
        return "\(type(of: self).self)(keys: \(self._storage.map { $0.key.name }))"
    }
}

/// Carried automatically by a "to do" baggage context.
/// It can be used to track where a context originated and which "to do" context must be fixed into a real one to avoid this.
public struct TODOLocation {
    let file: String
    let line: UInt
}
