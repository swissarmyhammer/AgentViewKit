import AppKit
import EditorStyle
import EditorSwiftUI
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing
import UniformTypeIdentifiers

@testable import AgentViewKit

/// A row of the kit that puts an SF Symbol before its text.
enum LeadingSymbolRow: String, CaseIterable, Sendable {
  /// An entry of a plan (`TaskListView`).
  case planEntry
  /// The row of a tool call (`ToolCallView`).
  case toolCall
  /// The header of a terminal (`TerminalView`).
  case terminalHeader
  /// A row of the activity timeline (`ActivityTimeline`).
  case activityEntry
  /// The title line of a status text (`StatusTitleLayout`, in a `StatusBar`).
  case statusBar
  /// The title line of an error card (`StatusTitleLayout`, in an `ErrorView`).
  case errorCard
  /// The title label of an artifact (`ArtifactView`).
  case artifactTitle

  /// The text of the rows. The text is long, so that the row with the symbol
  /// is the widest part of each view.
  static let text = "The agent reads the file and changes the parser"

  /// Makes the view that holds the row.
  ///
  /// - Returns: The view, with no frame of its own.
  /// - Throws: An error when the preview model makes no entry of the kind.
  func makeView() throws -> AnyView {
    switch self {
    case .planEntry:
      let plan = [PlanEntry(content: Self.text, priority: .high, status: .inProgress)]
      return AnyView(TaskListView(entry: try #require(PreviewFixtures.entry(.plan(plan), as: PlanTranscriptEntry.self))))
    case .toolCall:
      let item = PreviewTranscriptItem.toolCall(title: Self.text, kind: .read, status: .completed)
      return AnyView(ToolCallView(entry: try #require(PreviewFixtures.entry(item, as: ToolCallEntry.self))))
    case .terminalHeader:
      let item = PreviewTranscriptItem.terminal(command: Self.text, output: "", exitCode: 0)
      return AnyView(TerminalView(entry: try #require(PreviewFixtures.entry(item, as: TerminalEntry.self))))
    case .activityEntry:
      let item = PreviewTranscriptItem.toolCall(title: Self.text, kind: .edit, status: .pending)
      return AnyView(ActivityTimeline(session: .preview(transcript: [item])))
    case .statusBar:
      let message = StatusBar.Message(
        title: Self.text, explanation: "", symbolName: EditorSymbol.severity(.warning).systemImage,
        identifier: rawValue)
      return AnyView(StatusBar(message: message, action: nil))
    case .errorCard:
      let item = PreviewTranscriptItem.error(code: .internalError, message: Self.text)
      return AnyView(ErrorView(entry: try #require(PreviewFixtures.entry(item, as: ErrorEntry.self))))
    case .artifactTitle:
      let artifact = ArtifactPayload(id: rawValue, title: Self.text, type: UTType.plainText.identifier, inlineText: "")
      return AnyView(ArtifactView(artifact: artifact))
    }
  }
}

/// Tests that each row with a leading SF Symbol puts the symbol in the symbol
/// column of the style (EditorStyle `.symbolColumn()`), so the text of rows
/// with symbols of different widths starts at one x.
///
/// Each test hosts the view in an `NSHostingView` with no window and reads its
/// fitting width at two widths of the column. No test opens a window or
/// waits.
@Suite struct SymbolColumnRowTests {
  /// The amount by which the tests make the column wider than the default.
  /// The amount is large, so that the row with the symbol is the widest part
  /// of each view at the wider column.
  static let columnGrowth: CGFloat = 400

  /// The fitting width of a view at one width of the symbol column.
  ///
  /// - Parameters:
  ///   - view: The view to measure.
  ///   - columnWidth: The `symbolColumnWidth` of the style.
  /// - Returns: The width of the fitting size of the view.
  static func fittingWidth(of view: AnyView, columnWidth: CGFloat) -> CGFloat {
    var style = EditorStyle.default
    style.symbolColumnWidth = columnWidth
    return NSHostingView(rootView: view.editorStyle(style)).fittingSize.width
  }

  /// A production change that fails this test: a row gives its leading
  /// symbol a width of its own, or no fixed width, so the row does not grow
  /// with the column of the style.
  @Test("the row grows by the growth of the symbol column of the style", arguments: LeadingSymbolRow.allCases)
  func theRowTakesTheSymbolColumnOfTheStyle(_ row: LeadingSymbolRow) throws {
    let view = try row.makeView()
    let defaultWidth = EditorStyle.defaultSymbolColumnWidth
    let narrow = Self.fittingWidth(of: view, columnWidth: defaultWidth)
    let wide = Self.fittingWidth(of: view, columnWidth: defaultWidth + Self.columnGrowth)
    #expect(wide - narrow == Self.columnGrowth)
  }
}
