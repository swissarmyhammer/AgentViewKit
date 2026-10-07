import FoundationModelsACPClient
import SwiftUI

/// The consent card of a URL mode pending elicitation of a client model
/// (plan.md §13.3, §13.4; update.md §4.2 "Pending requests").
///
/// The card names the agent, shows the message, and shows the full URL of the
/// pending elicitation (`PendingElicitation.url`) with the host in bold
/// (``URLDisplay/highlighted(_:)``). When the host can look like a different
/// host, the card also shows the text of ``URLDisplay/warning(for:)``.
///
/// The card never opens or loads the URL by itself. Only a press on
/// "Open in Browser" opens it:
///
/// 1. The card starts ``AuthorizationPresenter/present(url:callbackScheme:ephemeral:)``
///    on the `authorizationPresenter` environment value. The browser session
///    runs in a task, because it ends only when the user closes the browser.
/// 2. The card then accepts the elicitation with no content: it calls
///    `acceptElicitation(_:content:)` on the ``PendingElicitationOwner`` that
///    holds the elicitation. The answer tells the agent that the user gave
///    consent. It does not wait for the browser.
/// 3. The card shows a waiting state until the model removes the request.
///    The accept removes the request at once, so the host then removes the
///    card.
///
/// Before the press, the card shows Cancel, Decline, and Open in Browser. In
/// the waiting state, the card shows Cancel and Retry. Retry opens the
/// browser again, and it does not send a second answer. Cancel calls
/// `cancelElicitation(_:)` and stops the browser session of the card. Esc
/// also calls `cancelElicitation(_:)`. A call for an elicitation that already
/// resolved changes nothing in the model.
///
/// The view keeps its state. Give each request its own view identity, for
/// example with `.id(request.id)`.
public struct ElicitationURLConsentView: View {
  /// The accessibility identifier of the card.
  public static let identifier = "elicitation-url-consent"
  /// The accessibility identifier of the URL text.
  public static let urlIdentifier = "elicitation-url"
  /// The accessibility identifier of the host warning.
  public static let warningIdentifier = "elicitation-url-warning"
  /// The accessibility identifier of the Open in Browser button.
  public static let openIdentifier = "elicitation-open"
  /// The accessibility identifier of the Retry button.
  public static let retryIdentifier = "elicitation-retry"
  /// The accessibility identifier of the Decline button.
  public static let declineIdentifier = ElicitationView.declineIdentifier
  /// The accessibility identifier of the Cancel button.
  public static let cancelIdentifier = ElicitationView.cancelIdentifier
  /// The accessibility identifier of the waiting state.
  public static let waitingIdentifier = "elicitation-waiting"

  /// The URL scheme that the browser session waits for.
  ///
  /// A URL mode request has no callback. The server gets the result on its
  /// own channel and sends `elicitation/complete`. No page opens this
  /// scheme, so the session stays open until the user closes the browser.
  public static let callbackScheme = "agentviewkit-elicitation"

  /// Whether the browser session shares no cookies with other sessions.
  ///
  /// The value is `false`, so that the user can use a sign-in that the
  /// browser already has.
  static let ephemeral = false

  /// The symbol of the warning.
  static let warningSymbol = "exclamationmark.triangle.fill"

  /// The step of the consent.
  enum Phase: Equatable {
    /// The user did not open the URL.
    case idle
    /// The user opened the URL. The card waits for `elicitation/complete`.
    case waiting
  }

  /// The pending elicitation to show.
  let request: PendingElicitation

  /// The model that holds the elicitation.
  let owner: any PendingElicitationOwner

  /// The step of the consent.
  @State private var phase: Phase = .idle

  /// The task that runs the browser session, or `nil`.
  @State private var browserTask: Task<Void, Never>?

  /// The presenter that the card uses when the environment has none.
  @State private var fallbackPresenter = AuthorizationPresenter()

  /// Whether the card has the keyboard focus.
  @FocusState private var isFocused: Bool

  @Environment(\.authorizationPresenter) private var presenter
  /// The action that moves the VoiceOver focus and tells the host.
  private let moveFocus = AccessibilityFocusMove()
  @Environment(\.agentTheme) private var theme

  /// Makes the consent card of a pending elicitation.
  ///
  /// - Parameters:
  ///   - request: A pending elicitation of `owner`. An elicitation with no
  ///     valid URL, such as a form mode elicitation, shows no URL, and its
  ///     Open in Browser button is disabled.
  ///   - owner: The model that holds the elicitation: a `SessionModel` or a
  ///     `ConnectionModel`.
  public init(request: PendingElicitation, owner: any PendingElicitationOwner) {
    self.request = request
    self.owner = owner
  }

  // MARK: Body

  public var body: some View {
    VStack(alignment: .leading, spacing: theme.spacing.m) {
      ElicitationHeader(request: request)
      if let url = request.url {
        urlSection(url)
      }
      if phase == .waiting {
        waiting
      }
      footer
    }
    .padding(theme.spacing.m)
    .frame(maxWidth: .infinity, alignment: .leading)
    .focusable()
    .focusEffectDisabled()
    .focused($isFocused)
    .onExitCommand(perform: cancel)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(Self.identifier)
    .accessibilityFocusTarget(Self.identifier)
    .onAppear {
      isFocused = true
      moveFocus(to: Self.identifier)
    }
    .onDisappear {
      browserTask?.cancel()
    }
  }

  /// The URL text, and the warning when the host needs one.
  ///
  /// - Parameter url: The URL of the request.
  /// - Returns: The section.
  private func urlSection(_ url: URL) -> some View {
    VStack(alignment: .leading, spacing: theme.spacing.xs) {
      Text(URLDisplay.highlighted(url))
        .font(.callout.monospaced())
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier(Self.urlIdentifier)
      if let warning = URLDisplay.warning(for: url) {
        Label(warning, systemImage: Self.warningSymbol)
          .font(.callout)
          .foregroundStyle(theme.statusColors.failed)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityElement(children: .ignore)
          .accessibilityLabel(warning)
          .accessibilityIdentifier(Self.warningIdentifier)
      }
    }
  }

  /// The waiting state.
  private var waiting: some View {
    HStack(spacing: theme.spacing.s) {
      ProgressView()
        .controlSize(.small)
      Text("Waiting for \(ElicitationHeader.agentServer) to finish")
        .foregroundStyle(.secondary)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Waiting for \(ElicitationHeader.agentServer) to finish")
    .accessibilityIdentifier(Self.waitingIdentifier)
  }

  /// The buttons of the current step.
  private var footer: some View {
    HStack(spacing: theme.spacing.s) {
      Spacer()
      Button("Cancel", role: .cancel, action: cancel)
        .accessibilityIdentifier(Self.cancelIdentifier)
      switch phase {
      case .idle:
        Button("Decline", action: decline)
          .accessibilityIdentifier(Self.declineIdentifier)
        Button("Open in Browser", action: open)
          .buttonStyle(.glassProminent)
          .disabled(request.url == nil)
          .accessibilityIdentifier(Self.openIdentifier)
      case .waiting:
        Button("Retry", action: openBrowser)
          .buttonStyle(.glassProminent)
          .accessibilityLabel("Open \(ElicitationHeader.agentServer) in the browser again")
          .accessibilityIdentifier(Self.retryIdentifier)
      }
    }
  }

  // MARK: Actions

  /// Opens the browser, sends the consent, and shows the waiting state.
  private func open() {
    guard phase == .idle, request.url != nil else { return }
    openBrowser()
    owner.acceptElicitation(request.id, content: nil)
    phase = .waiting
  }

  /// Starts a browser session on the URL of the request, in place of the
  /// session that the card started before.
  ///
  /// The session ends when the user closes the browser. The card ignores
  /// the result, because the server sends `elicitation/complete`. The new
  /// session starts only after the previous session stops, so that the stop
  /// of the previous session cannot stop the new session.
  private func openBrowser() {
    guard let url = request.url else { return }
    let previous = browserTask
    previous?.cancel()
    let presenter = presenter ?? fallbackPresenter
    browserTask = Task {
      await previous?.value
      _ = try? await presenter.present(
        url: url, callbackScheme: Self.callbackScheme, ephemeral: Self.ephemeral)
    }
  }

  /// Declines the elicitation.
  private func decline() {
    owner.declineElicitation(request.id)
  }

  /// Stops the browser session of the card and cancels the elicitation.
  private func cancel() {
    browserTask?.cancel()
    browserTask = nil
    owner.cancelElicitation(request.id)
  }
}

extension EnvironmentValues {
  /// The presenter that opens the browser for a URL mode elicitation, or
  /// `nil` for a presenter that each ``ElicitationURLConsentView`` makes.
  @Entry public var authorizationPresenter: AuthorizationPresenter? = nil
}
