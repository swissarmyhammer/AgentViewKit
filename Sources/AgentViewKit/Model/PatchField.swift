/// A field of a patch with three states (plan.md §3.2).
///
/// This is the ACP v2 upsert rule. An omitted field does not change the
/// stored value. A `null` field clears the stored value. A concrete value
/// replaces the stored value. The ACP wire package has the same type. The kit
/// defines its own copy, so that this target does not import ACP.
public nonisolated enum PatchField<Wrapped> {
  /// The patch does not change the stored value.
  case unchanged

  /// The patch clears the stored value: `nil`, or the empty value.
  case cleared

  /// The patch replaces the stored value with this value.
  case value(Wrapped)

  /// Puts this patch on top of an earlier patch of the same field.
  ///
  /// ``unchanged`` keeps the earlier patch. ``cleared`` and ``value(_:)``
  /// replace it.
  ///
  /// - Parameter previous: The earlier patch of the field.
  /// - Returns: The patch that has the effect of the two patches in order.
  public func folded(onto previous: PatchField<Wrapped>) -> PatchField<Wrapped> {
    switch self {
    case .unchanged: previous
    case .cleared, .value: self
    }
  }

  /// Applies the patch to an optional value.
  ///
  /// - Parameter current: The stored value.
  /// - Returns: The stored value for ``unchanged``, `nil` for ``cleared``,
  ///   and the new value for ``value(_:)``.
  public func applied(to current: Wrapped?) -> Wrapped? {
    switch self {
    case .unchanged: current
    case .cleared: nil
    case .value(let wrapped): wrapped
    }
  }

  /// Applies the patch to a value that is not optional.
  ///
  /// - Parameters:
  ///   - current: The stored value.
  ///   - clearedValue: The value that ``cleared`` sets.
  /// - Returns: The stored value for ``unchanged``, `clearedValue` for
  ///   ``cleared``, and the new value for ``value(_:)``.
  public func applied(to current: Wrapped, clearedValue: Wrapped) -> Wrapped {
    applied(to: Optional(current)) ?? clearedValue
  }
}

nonisolated extension PatchField where Wrapped: RangeReplaceableCollection {
  /// Applies the patch to a collection. ``cleared`` sets the empty
  /// collection.
  ///
  /// - Parameter current: The stored collection.
  /// - Returns: The collection after the patch.
  public func applied(to current: Wrapped) -> Wrapped {
    applied(to: current, clearedValue: Wrapped())
  }
}

nonisolated extension PatchField: Sendable where Wrapped: Sendable {}

nonisolated extension PatchField: Equatable where Wrapped: Equatable {}

nonisolated extension PatchField: Hashable where Wrapped: Hashable {}
