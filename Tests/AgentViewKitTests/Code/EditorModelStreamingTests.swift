import AgentViewKit
import EditorSwiftUI
import Testing

@Suite @MainActor struct EditorModelStreamingTests {
  // MARK: - syncStreaming

  // `syncStreaming(to:)` is the EditorKit method. These tests keep the
  // contract that the models of the code blocks and of the answers read.

  @Test func syncAppendsOnlyTheNewSuffix() {
    let model = EditorModel("let x")
    model.isReadOnly = true

    model.syncStreaming(to: "let x = 1")

    #expect(model.text == "let x = 1")
    #expect(model.isReadOnly)
  }

  @Test func syncReplacesTextThatIsNotAPrefix() {
    let model = EditorModel("old text")
    model.isReadOnly = true

    model.syncStreaming(to: "new")

    #expect(model.text == "new")
    #expect(model.isReadOnly)
  }

  @Test func syncWithTheSameTextDoesNotDispatch() {
    let model = EditorModel("same")
    let version = model.state.version

    model.syncStreaming(to: "same")

    #expect(model.text == "same")
    #expect(model.state.version == version)
  }
}
