import SwiftUI

/// The consent card of a URL mode elicitation request (plan.md §13.3,
/// §13.4).
///
/// The card names the server, shows the message, and shows the full URL with
/// the host in bold (``URLDisplay/highlighted(_:)``). When the host can look
/// like a different host, the card also shows the text of
/// ``URLDisplay/warning(for:)``.
///
/// The card never opens or loads the URL by itself. Only a press on
/// "Open in Browser" opens it:
///
/// 1. The card starts ``AuthorizationPresenter/present(url:callbackScheme:ephemeral:)``
///    on the `authorizationPresenter` environment value. The browser session
///    runs in a task, because it ends only when the user closes the browser.
/// 2. The card then sends ``ElicitationResult/accept(_:)`` with `nil` to
///    ``AgentThreadActions/respond(to:_:)-(ElicitationRequest,_)`` of the
///    `threadActions` environment value. The answer tells the server that
///    the user gave consent. It does not wait for the browser.
/// 3. The card shows a waiting state. The request stays in
///    ``AgentThread/pendingElicitations`` until the server sends
///    `elicitation/complete`. Then the host removes the card.
///
/// Before the press, the card shows Cancel, Decline, and Open in Browser. In
/// the waiting state, the card shows Cancel and Retry. Retry opens the
/// browser again, and it does not send a second answer. Cancel sends
/// ``ElicitationResult/cancel`` and stops the browser session of the card.
/// Esc also sends ``ElicitationResult/cancel``.
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

  /// The request to show.
  let request: ElicitationRequest

  /// The step of the consent.
  @State private var phase: Phase = .idle

  /// The task that runs the browser session, or `nil`.
  @State private var browserTask: Task<Void, Never>?

  /// The presenter that the card uses when the environment has none.
  @State private var fallbackPresenter = AuthorizationPresenter()

  /// Whether the card has the keyboard focus.
  @FocusState private var isFocused: Bool

  @Environment(\.threadActions) private var actions
  @Environment(\.authorizationPresenter) private var presenter
  @Environment(\.focusReporter) private var focusReporter
  @Environment(\.agentTheme) private var theme

  /// Makes the consent card of `request`.
  ///
  /// - Parameter request: The request to show. A form mode request shows no
  ///   URL and no Open in Browser button.
  public init(request: ElicitationRequest) {
    self.request = request
  }

  /// The URL of a request.
  ///
  /// - Parameter request: The request.
  /// - Returns: The URL of a URL mode request, else `nil`.
  static func url(of request: ElicitationRequest) -> URL? {
    guard case .url(let url, _) = request.mode else { return nil }
    return url
  }

  // MARK: Body

  public var body: some View {
    VStack(alignment: .leading, spacing: theme.spacing.m) {
      ElicitationHeader(request: request)
      if let url = Self.url(of: request) {
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
    .onAppear {
      isFocused = true
      focusReporter?.focusMoved(to: Self.identifier)
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
      Text("Waiting for \(request.server) to finish")
        .foregroundStyle(.secondary)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Waiting for \(request.server) to finish")
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
          .disabled(Self.url(of: request) == nil)
          .accessibilityIdentifier(Self.openIdentifier)
      case .waiting:
        Button("Retry", action: openBrowser)
          .buttonStyle(.glassProminent)
          .accessibilityLabel("Open \(request.server) in the browser again")
          .accessibilityIdentifier(Self.retryIdentifier)
      }
    }
  }

  // MARK: Actions

  /// Opens the browser, sends the consent, and shows the waiting state.
  private func open() {
    guard phase == .idle, Self.url(of: request) != nil else { return }
    openBrowser()
    respond(.accept(nil))
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
    guard let url = Self.url(of: request) else { return }
    let previous = browserTask
    previous?.cancel()
    let presenter = presenter ?? fallbackPresenter
    browserTask = Task {
      await previous?.value
      _ = try? await presenter.present(
        url: url, callbackScheme: Self.callbackScheme, ephemeral: Self.ephemeral)
    }
  }

  /// Sends ``ElicitationResult/decline``.
  private func decline() {
    respond(.decline)
  }

  /// Stops the browser session of the card and sends
  /// ``ElicitationResult/cancel``.
  private func cancel() {
    browserTask?.cancel()
    browserTask = nil
    respond(.cancel)
  }

  /// Sends `result` to the thread actions.
  ///
  /// - Parameter result: The answer of the user.
  private func respond(_ result: ElicitationResult) {
    actions.startRespond(to: request, result)
  }
}

extension EnvironmentValues {
  /// The presenter that opens the browser for a URL mode elicitation, or
  /// `nil` for a presenter that each ``ElicitationURLConsentView`` makes.
  @Entry public var authorizationPresenter: AuthorizationPresenter? = nil
}
