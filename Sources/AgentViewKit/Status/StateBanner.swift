import SwiftUI

/// A glass bar that tells the user that the thread needs attention
/// (plan.md §9 A).
///
/// Pass ``AgentThread/state`` as `state`. The bar shows for
/// ``ThreadState/requiresAction`` and for an idle thread that stopped with
/// ``StopReason/maxTokens``, ``StopReason/maxTurnRequests``, or
/// ``StopReason/refusal``. For each other state the view is empty.
///
/// When the host gives the identifier of the related error and an
/// `onShowError` closure, the bar shows a Show Error button. The host uses the
/// closure to move the conversation to the `ErrorView` of that error.
public struct StateBanner: View {
  /// The accessibility identifier of the bar.
  public static let bannerIdentifier = "state-banner"

  /// The accessibility identifier of the Show Error button.
  public static let showErrorIdentifier = "state-banner-show-error"

  /// The text that the bar shows for one state.
  public struct Message: Equatable, Sendable {
    /// The short title of the bar.
    public let title: String

    /// The explanation below the title.
    public let explanation: String

    /// The SF Symbol name of the bar.
    public let symbolName: String
  }

  /// The run state of the thread.
  let state: ThreadState

  /// The identifier of the error that relates to the state, or `nil`.
  let errorID: String?

  /// The host closure that shows the error, or `nil` for no button.
  let onShowError: ((String) -> Void)?

  @Environment(\.agentTheme) private var theme

  /// Makes the bar.
  ///
  /// - Parameters:
  ///   - state: The run state of the thread, such as ``AgentThread/state``.
  ///   - errorID: The identifier of the ``ThreadError`` that relates to the
  ///     state, or `nil` when there is none.
  ///   - onShowError: The host closure that shows the error. It gets
  ///     `errorID`.
  public init(
    state: ThreadState,
    errorID: String? = nil,
    onShowError: ((String) -> Void)? = nil
  ) {
    self.state = state
    self.errorID = errorID
    self.onShowError = onShowError
  }

  /// The text of the bar for `state`.
  ///
  /// - Parameter state: The run state of a thread.
  /// - Returns: The text, or `nil` when the bar does not show for `state`.
  public static func message(for state: ThreadState) -> Message? {
    switch state {
    case .running, .idle(nil), .idle(.endTurn), .idle(.cancelled), .idle(.unknown):
      nil
    case .requiresAction:
      Message(
        title: String(localized: "The agent needs your input"),
        explanation: String(localized: "Answer the request to let the agent continue."),
        symbolName: "hand.raised.fill")
    case .idle(.maxTokens):
      Message(
        title: String(localized: "The response is incomplete"),
        explanation: String(
          localized: "The model used its maximum number of output tokens. Ask it to continue."),
        symbolName: "text.badge.xmark")
    case .idle(.maxTurnRequests):
      Message(
        title: String(localized: "The turn stopped"),
        explanation: String(
          localized: "The turn used its maximum number of model requests. Send a message to continue."),
        symbolName: "arrow.trianglehead.2.clockwise.rotate.90")
    case .idle(.refusal):
      Message(
        title: String(localized: "The model refused to continue"),
        explanation: String(localized: "Change the request and send it again."),
        symbolName: "exclamationmark.bubble.fill")
    }
  }

  public var body: some View {
    if let message = Self.message(for: state) {
      HStack(spacing: theme.spacing.m) {
        Image(systemName: message.symbolName)
          .symbolRenderingMode(.hierarchical)
          .foregroundStyle(theme.accent)
          .fontWeight(theme.symbolWeight)
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
          Text(message.title)
            .font(.headline)
          Text(message.explanation)
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        Spacer(minLength: theme.spacing.s)
        if let errorID, let onShowError {
          Button("Show Error") { onShowError(errorID) }
            .buttonStyle(.glass)
            .accessibilityIdentifier(Self.showErrorIdentifier)
        }
      }
      .padding(theme.spacing.m)
      .glassEffect(theme.materialLevel.glass, in: .rect(cornerRadius: theme.radii.l))
      .accessibilityElement(children: .contain)
      .accessibilityLabel(message.title)
      .accessibilityIdentifier(Self.bannerIdentifier)
    }
  }
}
