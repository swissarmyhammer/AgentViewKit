import AgentViewKit
import EditorSwiftUI
import Testing

@Suite @MainActor struct EditorModelAppendTests {
  // MARK: - appendStreaming

  @Test func appendAddsTheTextAtTheEnd() {
    let model = EditorModel("a")

    let outcome = model.appendStreaming("b")

    #expect(model.text == "ab")
    #expect(outcome.applied != nil)
  }

  @Test func appendChangesAReadOnlyModelAndKeepsItReadOnly() {
    let model = EditorModel("let x = 1")
    model.isReadOnly = true

    let outcome = model.appendStreaming("\nlet y = 2")

    #expect(model.text == "let x = 1\nlet y = 2")
    #expect(outcome.applied != nil)
    #expect(model.isReadOnly)
  }

  @Test func appendKeepsAnEditableModelEditable() {
    let model = EditorModel("a")

    model.appendStreaming("b")

    #expect(!model.isReadOnly)
  }

  @Test func appendOfAnEmptyStringKeepsTheText() {
    let model = EditorModel("a")
    let version = model.state.version

    let outcome = model.appendStreaming("")

    #expect(model.text == "a")
    #expect(outcome.applied != nil)
    #expect(model.state.version == version)
  }

  @Test func appendCountsMultibyteTextInUTF8() {
    let model = EditorModel("é😀")

    model.appendStreaming("ü")

    #expect(model.text == "é😀ü")
  }

  @Test func appendToAnEmptyModel() {
    let model = EditorModel()

    model.appendStreaming("first")
    model.appendStreaming(" second")

    #expect(model.text == "first second")
  }

  // MARK: - syncStreaming

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
