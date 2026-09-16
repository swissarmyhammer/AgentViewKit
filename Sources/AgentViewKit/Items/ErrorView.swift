import SwiftUI

/// The default view of a ``ThreadError`` item (plan.md §9 A2).
///
/// The view is a glass card with a symbol, a title, a detail, and at most one
/// action button. The button shows only when the host gives its closure in
/// ``SwiftUI/EnvironmentValues/errorActions``.
///
/// | Kind | Detail | Action |
/// |------|--------|--------|
/// | `contextSizeExceeded` | Both token counts | Compact |
/// | `rateLimited` | The reset time | Retry |
/// | `guardrailViolation`, `refusal` | The explanation | Rephrase |
/// | `timeout` | A fixed text | Retry |
/// | `acp` | The code and the message | None |
/// | `unknown` | The message | None |
public struct ErrorView: View {
  /// The start of the accessibility identifier of each card.
  public static let identifierPrefix = "error-"

  /// The start of the accessibility identifier of each action button.
  public static let actionIdentifierPrefix = "error-action-"

  /// A button of the error card.
  public enum Action: String, CaseIterable, Hashable, Sendable {
    /// Compacts the thread.
    case compact
    /// Sends the request again.
    case retry
    /// Lets the user change the request.
    case rephrase

    /// The title of the button.
    public var title: String {
      switch self {
      case .compact: String(localized: "Compact")
      case .retry: String(localized: "Retry")
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

  /// The error to show.
  let error: ThreadError

  @Environment(\.errorActions) private var actions
  @Environment(\.agentTheme) private var theme

  /// Makes the card.
  ///
  /// - Parameter error: The error to show.
  public init(error: ThreadError) {
    self.error = error
  }

  /// The accessibility identifier of the card of `kind`.
  ///
  /// - Parameter kind: The type of the error.
  /// - Returns: `error-<case>`, for example `error-timeout`.
  public static func identifier(for kind: ThreadError.Kind) -> String {
    identifierPrefix + caseName(of: kind)
  }

  /// The accessibility identifier of the button of `action`.
  ///
  /// - Parameter action: A button of the card.
  /// - Returns: `error-action-<action>`, for example `error-action-retry`.
  public static func actionIdentifier(for action: Action) -> String {
    actionIdentifierPrefix + action.rawValue
  }

  /// The name of the case of `kind`, with no values.
  ///
  /// - Parameter kind: The type of the error.
  /// - Returns: The case name, for example `rateLimited`.
  static func caseName(of kind: ThreadError.Kind) -> String {
    switch kind {
    case .contextSizeExceeded: "contextSizeExceeded"
    case .rateLimited: "rateLimited"
    case .guardrailViolation: "guardrailViolation"
    case .refusal: "refusal"
    case .timeout: "timeout"
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
    case .contextSizeExceeded(let contextSize, let tokenCount):
      Content(
        title: String(localized: "The conversation is too long"),
        detail: String(
          localized:
            "The request has \(tokenCount.formatted()) tokens, but the context can hold \(contextSize.formatted()) tokens. Compact the conversation to continue."
        ),
        symbolName: "text.line.last.and.arrowtriangle.forward",
        action: .compact)
    case .rateLimited(let resetAt):
      Content(
        title: String(localized: "The rate limit is reached"),
        detail: resetAt.map {
          String(
            localized:
              "You can send again at \($0.formatted(date: .abbreviated, time: .shortened)).")
        } ?? String(localized: "Wait some time, then send again."),
        symbolName: "hourglass",
        action: .retry)
    case .guardrailViolation(let explanation):
      Content(
        title: String(localized: "A safety guardrail stopped the request"),
        detail: explanation ?? String(localized: "Change the request and send it again."),
        symbolName: "exclamationmark.shield.fill",
        action: .rephrase)
    case .refusal(let explanation):
      Content(
        title: String(localized: "The model refused the request"),
        detail: explanation ?? String(localized: "Change the request and send it again."),
        symbolName: "exclamationmark.bubble.fill",
        action: .rephrase)
    case .timeout:
      Content(
        title: String(localized: "The request took too long"),
        detail: String(localized: "The agent did not answer in time. Send the request again."),
        symbolName: "clock.badge.exclamationmark",
        action: .retry)
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
    let kind = error.kind
    let content = Self.content(for: kind)
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
      if let action = content.action, let handler = actions.handler(for: action) {
        Button(action.title) { handler(error) }
          .buttonStyle(.glass)
          .accessibilityIdentifier(Self.actionIdentifier(for: action))
      }
    }
    .padding(theme.spacing.m)
    .glassEffect(theme.materialLevel.glass, in: .rect(cornerRadius: theme.radii.l))
  }
}
