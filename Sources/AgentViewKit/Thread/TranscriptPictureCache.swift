import CoreGraphics
import EditorSwiftUI

/// A value whose pictures take memory: the bytes of its bitmaps.
nonisolated protocol TranscriptPictureMemory {
  /// The bytes of the bitmaps of the value.
  var pictureBytes: Int { get }
}

/// The pictures of the static text of a thread, with a bound on the bytes of
/// their bitmaps (card ^9ync5h3).
///
/// The cache keeps the newest values last. A new value that takes the bytes
/// past the bound drops the oldest values, as the height worker drops the
/// prepared parts of its oldest rows, or the values farthest from a place,
/// such as the rows farthest from the rows in view
/// (``insert(_:forKey:distance:)``). One value always stays, also when it
/// alone is past the bound.
nonisolated struct TranscriptPictureCache<Key: Hashable, Value: TranscriptPictureMemory> {
  /// The most bytes of the bitmaps that the cache keeps.
  let byteLimit: Int

  /// The kept values, by key.
  private var values: [Key: Value] = [:]

  /// The keys of the kept values, the newest last.
  private var order: [Key] = []

  /// The bytes of the bitmaps of the kept values.
  private(set) var byteCount = 0

  /// Makes an empty cache.
  ///
  /// - Parameter byteLimit: The most bytes of the bitmaps that the cache
  ///   keeps.
  init(byteLimit: Int) {
    self.byteLimit = byteLimit
  }

  /// The kept value of a key, or `nil`. A read does not make the value the
  /// newest.
  subscript(key: Key) -> Value? {
    values[key]
  }

  /// Keeps a value as the newest, and drops the oldest values past the
  /// bound.
  ///
  /// - Parameters:
  ///   - value: The value.
  ///   - key: The key of the value.
  mutating func insert(_ value: Value, forKey key: Key) {
    insert(value, forKey: key) { _ in .zero }
  }

  /// Keeps a value as the newest, and drops the values farthest from a
  /// place past the bound: the oldest value first of values at the same
  /// distance. The new value can be the value that goes, when it is the
  /// farthest.
  ///
  /// - Parameters:
  ///   - value: The value.
  ///   - key: The key of the value.
  ///   - distance: The distance of the value of a key from the place.
  mutating func insert(_ value: Value, forKey key: Key, distance: (Key) -> Int) {
    remove(key)
    values[key] = value
    order.append(key)
    byteCount += value.pictureBytes
    while byteCount > byteLimit, order.count > 1, let farthest = order.max(by: { distance($0) < distance($1) }) {
      remove(farthest)
    }
  }

  /// Drops the value of a key.
  ///
  /// - Parameter key: The key.
  mutating func remove(_ key: Key) {
    guard let old = values.removeValue(forKey: key) else { return }
    byteCount -= old.pictureBytes
    order.removeAll { $0 == key }
  }

  /// Drops each value.
  mutating func removeAll() {
    values = [:]
    order = []
    byteCount = .zero
  }
}

extension EditorStaticRendering: TranscriptPictureMemory {
  /// The bytes of the bitmap of the picture.
  nonisolated var pictureBytes: Int {
    image?.pictureBytes ?? .zero
  }
}

extension CGImage: TranscriptPictureMemory {
  /// The bytes of the bitmap.
  nonisolated var pictureBytes: Int {
    bytesPerRow * height
  }
}

extension Dictionary: TranscriptPictureMemory where Value: TranscriptPictureMemory {
  /// The bytes of the bitmaps of the values.
  nonisolated var pictureBytes: Int {
    values.reduce(.zero) { $0 + $1.pictureBytes }
  }
}
