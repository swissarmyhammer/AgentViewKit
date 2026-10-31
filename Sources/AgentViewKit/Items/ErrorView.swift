import EditorStyle
import EditorSwiftUI
import EditorTheme
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// The default view of an `ErrorEntry` of a `SessionModel` (plan.md §3.8
/// "Error rows", §9 A2).
///
/// The view is a card with a symbol, a title, and a detail with the JSON-RPC
/// code and the message of the entry. When the entry has `data`, the card
/// also shows the data as JSON. The view reads the entry object at the time
/// of the body. The model keeps the errors: the kit keeps no error list.
///
/// The card is a row of the transcript, or of the activity timeline. Both are
/// content, so the card has no fill and no glass. A separator stroke marks
/// its edge (`.inlineEdge(radius:)`, D113).
public struct ErrorView: View {
  /// The accessibility identifier of the text of each card.
  public static let identifier = "error-acp"

  /// The accessibility identifier of the JSON data of an error entry.
  public static let dataIdentifier = "error-data"

  /// The text and the symbol of a card.
  public struct Content: Equatable, Sendable {
    /// The short title of the card.
    public let title: String

    /// The text below the title.
    public let detail: String

    /// The SF Symbol name of the card.
    public let symbolName: String
  }

  /// The error entry to show.
  let entry: ErrorEntry

  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.editorTheme) private var editorTheme
  @Environment(\.themeSecondary) private var themeSecondary

  /// Makes the card of an error entry of a `SessionModel`.
  ///
  /// - Parameter entry: The error entry to show.
  public init(entry: ErrorEntry) {
    self.entry = entry
  }

  /// The content of the card of an ACP JSON-RPC error.
  ///
  /// - Parameters:
  ///   - code: The JSON-RPC error code.
  ///   - message: The error message.
  /// - Returns: The title, the detail with the code and the message, and the
  ///   symbol.
  public static func content(code: Int, message: String) -> Content {
    Content(
      title: String(localized: "The agent sent an error", bundle: .module),
      detail: String(localized: "Error \(String(code)): \(message)", bundle: .module),
      symbolName: SharedSymbol.error)
  }

  public var body: some View {
    let content = Self.content(code: entry.code.wireValue, message: entry.message)
    ContentTileStack {
      // The text is the element of the card. A container element here merges
      // into the element of an `ItemRow` and loses its identifier.
      StatusTitleLayout(
        title: content.title, explanation: content.detail,
        textLabel: String(localized: "\(content.title), \(content.detail)", bundle: .module),
        identifier: Self.identifier
      ) {
        StatusSymbolImage(name: content.symbolName, color: editorTheme.severityError)
          .accessibilityHidden(true)
      }
    } body: {
      if let data = entry.data?.prettyPrinted {
        Text(data)
          .font(editorTheme.codeFont)
          .foregroundStyle(themeSecondary)
          .textSelection(.enabled)
          .accessibilityIdentifier(Self.dataIdentifier)
      }
    }
    .contentTile()
    .inlineEdge(radius: editorStyle.radii.l)
  }
}

#Preview("Error") {
  if let entry = PreviewFixtures.entry(
    .error(code: .internalError, message: "The agent stopped before it sent an answer."), as: ErrorEntry.self)
  {
    ErrorView(entry: entry)
  }
}
