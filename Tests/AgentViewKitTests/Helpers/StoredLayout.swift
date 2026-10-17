import Testing

/// The byte layout of a list of stored fields of a struct type.
///
/// Before SwiftUI can call `==` for a view type, it compares the bytes of the
/// old and the new view value (task ^fzn2beh). A padding byte has no defined
/// value, so two equal values can have different bytes there. A type with no
/// padding byte has no such gap.
///
/// The stored fields of a struct do not overlap, and each one is inside the
/// first ``size`` bytes of the value. Thus when the list holds each stored
/// field one time, ``size`` minus the sum of the field sizes is the number of
/// bytes that no field covers: the padding bytes. A list with a missing field
/// gives a larger number, so the check also fails when a new field is not in
/// the list.
struct StoredLayout<Root> {
  /// The size of `Root` in bytes, with no trailing padding.
  let size = MemoryLayout<Root>.size

  /// The offset of each listed field in `Root`, or `nil` for a key path that
  /// gives no offset. See ``offsetlessFieldCount``.
  let offsets: [Int?]

  /// The size in bytes of the value of each listed field.
  let fieldSizes: [Int]

  /// Reads the layout of the listed fields of `Root`.
  ///
  /// - Parameter fields: The key path of each stored field of `Root`.
  init<each Value>(_ fields: repeat KeyPath<Root, each Value>) {
    // A value pack has no `map`, so the loop is the one way to read each
    // field of the pack.
    var offsets: [Int?] = []
    var fieldSizes: [Int] = []
    for field in repeat each fields {
      offsets.append(MemoryLayout<Root>.offset(of: field))
      fieldSizes.append(Self.valueSize(of: field))
    }
    self.offsets = offsets
    self.fieldSizes = fieldSizes
  }

  /// The size in bytes of the value of a field.
  ///
  /// - Parameter field: The key path of the field.
  /// - Returns: `MemoryLayout<Value>.size`.
  private static func valueSize<Value>(of field: KeyPath<Root, Value>) -> Int {
    MemoryLayout<Value>.size
  }

  /// The number of listed key paths that give no offset.
  ///
  /// A key path to a computed property gives no offset. A key path to a
  /// stored field of a function type also gives no offset, because the key
  /// path changes the form of the function value.
  var offsetlessFieldCount: Int {
    offsets.count { $0 == nil }
  }

  /// `true` when no two listed key paths with an offset are at the same
  /// offset.
  var hasDistinctOffsets: Bool {
    let known = offsets.compactMap(\.self)
    return Set(known).count == known.count
  }

  /// The number of bytes of `Root` that no listed field covers.
  var uncoveredByteCount: Int {
    size - fieldSizes.reduce(0, +)
  }

  /// Records an issue when the listed key paths are not distinct stored
  /// fields, or when `Root` has a byte that no listed field covers. The
  /// comment of each issue gives the layout.
  ///
  /// - Parameters:
  ///   - functionFieldCount: The number of listed stored fields of a
  ///     function type. Each one gives no offset.
  ///   - sourceLocation: The place of the check in the test.
  func expectNoPaddingByte(
    functionFieldCount: Int = 0, sourceLocation: SourceLocation = #_sourceLocation
  ) {
    let layout = "\(Root.self): size \(size), offsets \(offsets), field sizes \(fieldSizes)"
    #expect(offsetlessFieldCount == functionFieldCount, "\(layout)", sourceLocation: sourceLocation)
    #expect(hasDistinctOffsets, "\(layout)", sourceLocation: sourceLocation)
    #expect(uncoveredByteCount == 0, "\(layout)", sourceLocation: sourceLocation)
  }
}
