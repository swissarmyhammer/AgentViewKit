import AgentViewKit
import EditorSwiftUI
import Testing

@Suite @MainActor struct CodeBlockModelCacheTests {
  static let first = CodeBlockID(messageID: "message-1", paragraphID: "paragraph-1")
  static let second = CodeBlockID(messageID: "message-1", paragraphID: "paragraph-2")
  static let other = CodeBlockID(messageID: "message-2", paragraphID: "paragraph-1")

  // MARK: - Identity

  @Test func theSameIDGivesTheSameModel() {
    let cache = CodeBlockModelCache()

    let model = cache.model(for: Self.first, code: "let x = 1")
    let again = cache.model(for: Self.first, code: "let x = 1")

    #expect(model === again)
    #expect(cache.count == 1)
  }

  @Test func aNewModelIsReadOnlyAndHoldsTheCode() {
    let cache = CodeBlockModelCache()

    let model = cache.model(for: Self.first, code: "let x = 1")

    #expect(model.text == "let x = 1")
    #expect(model.isReadOnly)
  }

  @Test func aCachedModelKeepsItsTextWhenTheCodeChanges() {
    let cache = CodeBlockModelCache()
    let model = cache.model(for: Self.first, code: "let x = 1")

    let again = cache.model(for: Self.first, code: "different")

    #expect(again === model)
    #expect(again.text == "let x = 1")
  }

  @Test func differentIDsGiveDifferentModels() {
    let cache = CodeBlockModelCache()

    let first = cache.model(for: Self.first, code: "a")
    let second = cache.model(for: Self.second, code: "a")
    let other = cache.model(for: Self.other, code: "a")

    #expect(first !== second)
    #expect(first !== other)
    #expect(cache.count == 3)
    #expect(cache.contains(Self.first))
  }

  // MARK: - Eviction

  @Test func evictRemovesEachModelOfTheMessage() {
    let cache = CodeBlockModelCache()
    let first = cache.model(for: Self.first, code: "a")
    _ = cache.model(for: Self.second, code: "b")
    let other = cache.model(for: Self.other, code: "c")

    cache.evict(messageID: "message-1")

    #expect(cache.count == 1)
    #expect(!cache.contains(Self.first))
    #expect(!cache.contains(Self.second))
    #expect(cache.contains(Self.other))
    #expect(cache.model(for: Self.other, code: "c") === other)
    #expect(cache.model(for: Self.first, code: "a") !== first)
  }

  @Test func evictOfAnUnknownMessageChangesNothing() {
    let cache = CodeBlockModelCache()
    _ = cache.model(for: Self.first, code: "a")

    cache.evict(messageID: "missing")

    #expect(cache.count == 1)
  }

  @Test func removeAllEmptiesTheCache() {
    let cache = CodeBlockModelCache()
    _ = cache.model(for: Self.first, code: "a")
    _ = cache.model(for: Self.other, code: "b")

    cache.removeAll()

    #expect(cache.count == 0)
  }

  // MARK: - Limit

  /// The limit of the caches of the limit tests: the first two models fill
  /// the cache.
  static let smallLimit = 2

  /// Fills a cache of ``smallLimit`` models with the models of ``first``
  /// and ``second``, uses the model of ``first`` again, and then adds the
  /// model of ``other``.
  ///
  /// - Returns: The cache.
  static func cacheThatWentPastItsLimit() -> CodeBlockModelCache {
    let cache = CodeBlockModelCache(limit: smallLimit)
    _ = cache.model(for: first, code: "a")
    _ = cache.model(for: second, code: "b")
    _ = cache.model(for: first, code: "a")
    _ = cache.model(for: other, code: "c")
    return cache
  }

  /// A production change that fails this test: the cache has no limit, so
  /// a long scroll keeps the model of each row that the thread showed.
  @Test func aCacheKeepsNoMoreModelsThanItsLimit() {
    #expect(Self.cacheThatWentPastItsLimit().count == Self.smallLimit)
  }

  /// A production change that fails this test: a full cache drops a model
  /// that was used after the oldest model, not the model used least
  /// recently.
  @Test func aFullCacheDropsTheModelUsedLeastRecently() {
    #expect(!Self.cacheThatWentPastItsLimit().contains(Self.second))
  }

  /// A production change that fails this test: a full cache drops the
  /// model that was made first, also when a view used it again since.
  @Test func aFullCacheKeepsAModelThatWasUsedAgain() {
    #expect(Self.cacheThatWentPastItsLimit().contains(Self.first))
  }

  /// A production change that fails this test: a cache with no limit drops
  /// models.
  @Test func aCacheWithNoLimitKeepsEachModel() {
    let cache = CodeBlockModelCache()
    let ids = (0..<Self.manyModelCount).map {
      CodeBlockID(messageID: "message-\($0)", paragraphID: "paragraph")
    }

    for id in ids {
      _ = cache.model(for: id, code: "a")
    }

    #expect(cache.count == Self.manyModelCount)
  }

  /// The number of models in the test of a cache with no limit.
  static let manyModelCount = 100
}
