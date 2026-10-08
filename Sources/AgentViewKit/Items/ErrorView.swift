import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// The default view of an `ErrorEntry` of a `SessionModel` (plan.md §3.8
/// "Error rows", §9 A2).
///
/// The view is a glass card with a symbol, a title, and a detail with the
/// JSON-RPC code and the message of the entry. When the entry has `data`, the
/// card also shows the data as JSON. The view reads the entry object at the
/// time of the body. The model keeps the errors: the kit keeps no error list.
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

  @Environment(\.agentTheme) private var theme

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
      title: String(localized: "The agent sent an error"),
      detail: String(localized: "Error \(String(code)): \(message)"),
      symbolName: "exclamationmark.triangle.fill")
  }

  public var body: some View {
    let content = Self.content(code: entry.code.wireValue, message: entry.message)
    VStack(alignment: .leading, spacing: theme.spacing.s) {
      HStack(alignment: .top, spacing: theme.spacing.m) {
        Image(systemName: content.symbolName)
          .symbolRenderingMode(.hierarchical)
          .foregroundStyle(theme.statusColors.failed)
          .fontWeight(theme.symbolWeight)
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
          Text(content.title)
            .font(.headline)
          Text(content.detail)
            .font(.callout)
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
        }
        // The text is the element of the card. A container element here
        // merges into the element of an `ItemRow` and loses its identifier.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(content.title), \(content.detail)")
        .accessibilityIdentifier(Self.identifier)
        Spacer(minLength: theme.spacing.s)
      }
      if let data = entry.data?.prettyPrinted {
        Text(data)
          .font(theme.codeFont)
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
          .accessibilityIdentifier(Self.dataIdentifier)
      }
    }
    .padding(theme.spacing.m)
    .glassEffect(theme.materialLevel.glass, in: .rect(cornerRadius: theme.radii.l))
  }
}
