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

/// `BaggageKey`s are used as keys in a `Baggage`. Their associated type `Value` guarantees type-safety.
/// To give your `BaggageKey` an explicit name you may override the `name` property.
///
/// In general, `BaggageKey`s should be `internal` or `private` to the part of a system using it.
///
/// All access to baggage items should be performed through an accessor computed property defined as shown below:
///
///     private enum TestIDKey: Baggage.Key {
///         typealias Value = String
///         static var name: String? { "test-id" }
///     }
///
///     extension Baggage {
///         /// This is some useful property documentation.
///         var testID: String? {
///             get {
///                 self[TestIDKey.self]
///             }
///             set {
///                 self[TestIDKey.self] = newValue
///             }
///         }
///     }
public protocol BaggageKey {
    /// The type of `Value` uniquely identified by this key.
    associatedtype Value

    /// The human-readable name of this key.
    /// May be used as key during serialization of the baggage item.
    ///
    /// Defaults to `nil`.
    static var name: String? { get }
}

extension BaggageKey {
    public static var name: String? { return nil }
}

/// A type-erased `BaggageKey` used when iterating through the `Baggage` using its `forEach` method.
public struct AnyBaggageKey {
    /// The key's type represented erased to an `Any.Type`.
    public let keyType: Any.Type

    private let _name: String?

    /// A human-readable String representation of the underlying key.
    /// If no explicit name has been set on the wrapped key the type name is used.
    public var name: String {
        return self._name ?? String(describing: self.keyType.self)
    }

    init<Key>(_ keyType: Key.Type) where Key: BaggageKey {
        self.keyType = keyType
        self._name = keyType.name
    }
}

extension AnyBaggageKey: Hashable {
    public static func == (lhs: AnyBaggageKey, rhs: AnyBaggageKey) -> Bool {
        return ObjectIdentifier(lhs.keyType) == ObjectIdentifier(rhs.keyType)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self.keyType))
    }
}
