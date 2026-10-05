import FoundationModelsACPClient
import SwiftUI

/// The default view of a ``ThreadError`` item or of an `ErrorEntry` of a
/// `SessionModel` (plan.md §9 A2; update.md §4.7 "Error rows").
///
/// The view is a glass card with a symbol, a title, a detail, and at most one
/// action button. The button shows only when the host gives its closure in
/// ``SwiftUI/EnvironmentValues/errorActions``.
///
/// | Kind | Detail | Action |
/// |------|--------|--------|
/// | `refusal` | The explanation | Rephrase |
/// | `acp` | The code and the message | None |
/// | `unknown` | The message | None |
///
/// An `ErrorEntry` shows as the `acp` kind, with its JSON-RPC code and its
/// message. When the entry has `data`, the card also shows the data as JSON.
/// The model keeps the errors: the kit keeps no error list.
public struct ErrorView: View {
  /// The start of the accessibility identifier of each card.
  public static let identifierPrefix = "error-"

  /// The start of the accessibility identifier of each action button.
  public static let actionIdentifierPrefix = "error-action-"

  /// The accessibility identifier of the JSON data of an error entry.
  public static let dataIdentifier = "error-data"

  /// A button of the error card.
  public enum Action: String, CaseIterable, Hashable, Sendable {
    /// Lets the user change the request.
    case rephrase

    /// The title of the button.
    public var title: String {
      switch self {
      case .rephrase: String(localized: "Rephrase")
      }
    }
  }

  /// The text, the symbol, and the action of the card for one error kind.
  public struct Content: Equatable, Sendable {
    /// The short title of the card.
    public let title: String

    /// The text below the title.
    public let detail: String

    /// The SF Symbol name of the card.
    public let symbolName: String

    /// The button of the card, or `nil` for no button.
    public let action: Action?
  }

  /// The error that the card shows.
  enum Source {
    /// An error item of an ``AgentThread``.
    case record(ThreadError)

    /// An error entry of the transcript of a `SessionModel`.
    case entry(ErrorEntry)

    /// The type of the error and its values.
    var kind: ThreadError.Kind {
      switch self {
      case .record(let error): error.kind
      case .entry(let entry): .acp(code: entry.code.wireValue, message: entry.message)
      }
    }

    /// The JSON-RPC data of the error as pretty-printed JSON, or `nil`.
    var data: String? {
      switch self {
      case .record: nil
      case .entry(let entry): entry.data.map { SessionUpdateMapping.json($0).prettyPrinted }
      }
    }
  }

  /// The error to show.
  let source: Source

  @Environment(\.errorActions) private var actions
  @Environment(\.agentTheme) private var theme

  /// Makes the card.
  ///
  /// - Parameter error: The error to show.
  public init(error: ThreadError) {
    self.source = .record(error)
  }

  /// Makes the card of an error entry of a `SessionModel`.
  ///
  /// The card shows the JSON-RPC code, the message and the data of the
  /// entry. It shows no action.
  ///
  /// - Parameter entry: The error entry to show.
  public init(entry: ErrorEntry) {
    self.source = .entry(entry)
  }

  /// The accessibility identifier of the card of `kind`.
  ///
  /// - Parameter kind: The type of the error.
  /// - Returns: `error-<case>`, for example `error-refusal`.
  public static func identifier(for kind: ThreadError.Kind) -> String {
    AccessibilityIdentifier.make(prefix: identifierPrefix, value: caseName(of: kind))
  }

  /// The accessibility identifier of the button of `action`.
  ///
  /// - Parameter action: A button of the card.
  /// - Returns: `error-action-<action>`, for example `error-action-rephrase`.
  public static func actionIdentifier(for action: Action) -> String {
    AccessibilityIdentifier.make(prefix: actionIdentifierPrefix, value: action.rawValue)
  }

  /// The name of the case of `kind`, with no values.
  ///
  /// - Parameter kind: The type of the error.
  /// - Returns: The case name, for example `refusal`.
  static func caseName(of kind: ThreadError.Kind) -> String {
    switch kind {
    case .refusal: "refusal"
    case .acp: "acp"
    case .unknown: "unknown"
    }
  }

  /// The content of the card for `kind`.
  ///
  /// - Parameter kind: The type of the error and its values.
  /// - Returns: The title, the detail, the symbol, and the action.
  public static func content(for kind: ThreadError.Kind) -> Content {
    switch kind {
    case .refusal(let explanation):
      Content(
        title: String(localized: "The model refused the request"),
        detail: explanation ?? String(localized: "Change the request and send it again."),
        symbolName: "exclamationmark.bubble.fill",
        action: .rephrase)
    case .acp(let code, let message):
      Content(
        title: String(localized: "The agent sent an error"),
        detail: String(localized: "Error \(String(code)): \(message)"),
        symbolName: "exclamationmark.triangle.fill",
        action: nil)
    case .unknown(let message):
      Content(
        title: String(localized: "An error occurred"),
        detail: message,
        symbolName: "exclamationmark.octagon.fill",
        action: nil)
    }
  }

  public var body: some View {
    let kind = source.kind
    let content = Self.content(for: kind)
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
        // The text is the element of the card, and the button is its sibling.
        // A container element here merges into the element of an `ItemRow`
        // and loses its identifier.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(content.title), \(content.detail)")
        .accessibilityIdentifier(Self.identifier(for: kind))
        Spacer(minLength: theme.spacing.s)
        actionButton(content.action)
      }
      if let data = source.data {
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

  /// The button of `action`, when the host gives its closure and the card
  /// shows an error item.
  ///
  /// - Parameter action: The action of the card, or `nil`.
  /// - Returns: The button, or nothing.
  @ViewBuilder private func actionButton(_ action: Action?) -> some View {
    if let action, case .record(let error) = source, let handler = actions.handler(for: action) {
      Button(action.title) { handler(error) }
        .buttonStyle(.glass)
        .accessibilityIdentifier(Self.actionIdentifier(for: action))
    }
  }
}
