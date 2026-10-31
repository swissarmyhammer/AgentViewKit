import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import EditorSwiftUI
import EditorTestSupport
import EditorTheme
import SwiftUI
import Testing

/// Checks ``InspectorForm`` in a window: the shell, the name row and the font.
@Suite(.serialized, .hostedSerially) @MainActor struct InspectorFormHostedTests {
  /// The size of the window: about the width of an inspector column.
  static let size = CGSize(width: 320, height: 600)

  /// The accessibility identifier of the form.
  static let formIdentifier = "test-form"

  /// The accessibility identifier of the name row.
  static let nameIdentifier = "test-name"

  /// The accessibility identifier of a row of the content.
  static let rowIdentifier = "test-row"

  /// The accessibility identifier of the action of the form.
  static let actionIdentifier = "test-action"

  /// A short name.
  static let shortName = "Name"

  /// A name that is much wider than the window.
  static let longName = String(repeating: "A long name ", count: 40)

  /// The fonts that a row of the form reads.
  final class FontRecord {
    /// The fonts, in the order of the reads.
    var fonts: [Font?] = []
  }

  /// Records the font of its environment as its body runs.
  struct FontRecorder: View {
    /// The fonts that the body read.
    let record: FontRecord

    @Environment(\.font) private var font

    var body: some View {
      record.fonts.append(font)
      return Text(verbatim: "Row")
    }
  }

  /// Makes a form with a name, an action and one row.
  ///
  /// - Parameter name: The name of the form.
  /// - Returns: The form.
  static func namedForm(_ name: String) -> some View {
    InspectorForm(name: name, nameIdentifier: nameIdentifier) {
      Button("Action") {}
        .accessibilityIdentifier(actionIdentifier)
    } content: {
      Section {
        Text(verbatim: "Row")
          .accessibilityIdentifier(rowIdentifier)
      }
    }
    .accessibilityIdentifier(formIdentifier)
  }

  /// Mounts `view` in a window of ``size``, and makes one render pass.
  ///
  /// - Parameter view: The view to show.
  /// - Returns: The harness. The caller closes it.
  static func mount<Content: View>(_ view: Content) -> HostedViewHarness<Content> {
    let harness = HostedViewHarness(view, size: size)
    harness.render()
    return harness
  }

  @Test func theFormIsAScrollingForm() throws {
    let harness = Self.mount(Self.namedForm(Self.shortName))
    defer { harness.close() }

    let form = try #require(harness.element(identifier: Self.formIdentifier))
    #expect(form.role == NSAccessibility.Role.scrollArea.rawValue)
  }

  @Test func theFormHoldsTheNameTheActionsAndTheContent() {
    let harness = Self.mount(Self.namedForm(Self.shortName))
    defer { harness.close() }

    let inForm = Set(harness.elements(under: Self.formIdentifier).compactMap(\.identifier))
    #expect(inForm.isSuperset(of: [Self.nameIdentifier, Self.actionIdentifier, Self.rowIdentifier]))
  }

  @Test func theNameRowReadsAsTheName() {
    let harness = Self.mount(Self.namedForm(Self.shortName))
    defer { harness.close() }

    #expect(harness.element(identifier: Self.nameIdentifier)?.label == Self.shortName)
  }

  @Test func aLongNameStaysOnOneLine() throws {
    let short = Self.mount(Self.namedForm(Self.shortName))
    defer { short.close() }
    let long = Self.mount(Self.namedForm(Self.longName))
    defer { long.close() }

    let shortFrame = try #require(short.frame(identifier: Self.nameIdentifier))
    let longFrame = try #require(long.frame(identifier: Self.nameIdentifier))
    #expect(longFrame.height == shortFrame.height)
  }

  @Test func theShellHasNoNameRow() {
    let harness = Self.mount(
      InspectorForm {
        Section {
          Text(verbatim: "Row")
            .accessibilityIdentifier(Self.rowIdentifier)
        }
      })
    defer { harness.close() }

    #expect(harness.element(identifier: Self.rowIdentifier) != nil)
    #expect(harness.element(identifier: Self.nameIdentifier) == nil)
  }

  @Test func theRowsTakeTheUIFontRole() {
    let record = FontRecord()
    let harness = Self.mount(
      InspectorForm {
        Section {
          FontRecorder(record: record)
        }
      })
    defer { harness.close() }

    #expect(record.fonts.last == EnvironmentValues().editorTheme.uiFont)
  }
}
