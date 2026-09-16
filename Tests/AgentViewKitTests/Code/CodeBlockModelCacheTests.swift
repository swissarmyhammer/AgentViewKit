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
}
