import AgentViewKitStyle
import EditorSwiftUI
import EditorTheme
import SwiftUI
import Testing

/// Checks the note of the shared diff content through its public API.
@Suite @MainActor struct DiffContentViewTests {
  /// A label style that records the font of the label it draws.
  struct FontRecordingLabelStyle: LabelStyle {
    /// The fonts that the label drew with.
    let record: StyleRecord<Font?>

    func makeBody(configuration: Configuration) -> some View {
      FontRecorder(record: record)
    }
  }

  /// Records the font of its environment as its body runs.
  struct FontRecorder: View {
    /// The fonts that the body read.
    let record: StyleRecord<Font?>

    @Environment(\.font) private var font

    var body: some View {
      record.values.append(font)
      return Color.clear
    }
  }

  @Test func theNoteTakesTheUIFontRole() {
    let record = StyleRecord<Font?>()

    StyleViewHost.layOut(
      DiffContentView(note: "Binary file changed", systemImage: SharedSymbol.binary, identifier: "note")
        .labelStyle(FontRecordingLabelStyle(record: record))
        .editorTheme(.system))

    #expect(record.values.last == EnvironmentValues().editorTheme.uiFont)
  }
}
