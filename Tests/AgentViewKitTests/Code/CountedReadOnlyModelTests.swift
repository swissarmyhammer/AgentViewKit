#if DEBUG
  @testable import AgentViewKit
  import EditorSwiftUI
  import Testing

  /// The read-only model that adds one ``BodyEvaluationCounter`` count each
  /// time a view makes it. The code blocks and the rendered Markdown make
  /// their models with it.
  @Suite @MainActor struct CountedReadOnlyModelTests {
    /// The key prefix of these tests. No other test uses it.
    static let keyPrefix = "counted-read-only-model-test-"

    @Test func theKeyIsThePrefixAndThenTheText() {
      let key = EditorModel.readOnlyCounterKey(for: "let x", keyPrefix: "prefix-")

      #expect(key == "prefix-let x")
    }

    @Test func eachModelAddsOneCountToItsKey() {
      let text = "count once"
      let key = EditorModel.readOnlyCounterKey(for: text, keyPrefix: Self.keyPrefix)
      BodyEvaluationCounter.reset(key)

      _ = EditorModel.makeCountedReadOnly(text, keyPrefix: Self.keyPrefix)

      #expect(BodyEvaluationCounter.count(key) == 1)
    }

    @Test func theModelHoldsTheText() {
      let model = EditorModel.makeCountedReadOnly("let y", keyPrefix: Self.keyPrefix)

      #expect(model.text == "let y")
    }

    @Test func theModelIsReadOnly() {
      let model = EditorModel.makeCountedReadOnly("let z", keyPrefix: Self.keyPrefix)

      #expect(model.isReadOnly)
    }
  }
#endif
