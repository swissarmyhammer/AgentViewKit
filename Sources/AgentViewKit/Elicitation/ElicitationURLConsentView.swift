import EditorSwiftUI
import EditorTheme
import FoundationModelsACPClient
import SwiftUI

/// The consent card of a URL mode pending elicitation of a client model
/// (plan.md §3.2 "Pending requests", §13.3, §13.4).
///
/// The card names the agent, shows the message, and shows the full URL of the
/// pending elicitation (`PendingElicitation.url`) with the host in bold
/// (``URLDisplay/highlighted(_:)``), in the code font: the `editorFont` role
/// of the EditorKit theme. When the host can look like a different
/// host, the card also shows the text of ``URLDisplay/warning(for:)``.
///
/// The header of the card is ``ElicitationHeader``, or the override of
/// ``SwiftUI/View/elicitationHeader(_:)`` when the environment has one, as on
/// the form card of ``ElicitationView``. The consent state and the waiting
/// state show the same header.
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
/// 3. The accept moves the request to `awaitingURLCompletions` of the owner,
///    with the same id. While the owner holds it there, the card shows the
///    waiting state "Waiting for <host> to finish" (identifier
///    ``waitingIdentifier``), where <host> is
///    `PendingElicitation.waitingHostName`: the host of the URL, or the agent
///    when the URL has no host.
///    The owner removes the request when the agent sends
///    `elicitation/complete`, and then the host removes the card.
///
/// Before the press, the card shows Cancel, Decline, and Open in Browser.
/// Cancel and Esc call `cancelElicitation(_:)`. In the waiting state, the card
/// shows Cancel and Retry. Retry opens the browser again, and it does not
/// send a second answer. In the waiting state, Cancel and Esc stop the
/// browser session of the card and call `stopWaiting(_:)`, which sends
/// nothing to the agent. The Cancel button of the waiting state has the same
/// label, symbol, role and identifier as the Cancel button before the press. A
/// call for an elicitation that already resolved changes nothing in the
/// model.
///
/// The card reads the waiting state from the owner, so a new card for an
/// accepted request shows the waiting state. The browser session runs in the
/// state of the view, and the card stops it when it goes away. Give each
/// request its own view identity, for example with `.id(request.id)`.
/// ``RequestDeck`` keeps the same card, with the same identity, from the
/// accept to the end of the wait.
///
/// The card does not move the VoiceOver focus or the keyboard focus when it
/// appears. The ``RequestDeck`` announces the new request and moves the
/// focus. The deck gives the card the keyboard focus when the user brings it
/// to the front with Next, and then Esc cancels the request of the card.
///
/// The URL text and the warning do not use a fixed vertical size. A text
/// with a fixed vertical size gives its full wrapped height at a narrow
/// width as its minimum height. ``AgentThreadView`` shows the card outside
/// its scroll view, so a `NavigationSplitView` column then gives that large
/// minimum size to its window.
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
  static let warningSymbol = SharedSymbol.warning
  /// The symbol of the Open in Browser button, which opens the URL in an
  /// other app.
  static let openSymbol = SharedSymbol.open
  /// The symbol of the Retry button, which opens the browser again.
  static let retrySymbol = SharedSymbol.reload
  /// The symbol of the Decline button: the symbol of the form.
  static let declineSymbol = ElicitationView.declineSymbol
  /// The symbol of the Cancel button: the symbol of the form.
  static let cancelSymbol = ElicitationView.cancelSymbol

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

  /// The step of the consent, from the model: `.waiting` while the owner
  /// holds the request in `awaitingURLCompletions`, else `.idle`.
  private var phase: Phase {
    owner.awaitingURLCompletions.contains { $0.id == request.id } ? .waiting : .idle
  }

  /// The host that the waiting step names: the host of the URL, or the
  /// agent when the URL has no host.
  private var waitingHost: String {
    request.waitingHostName
  }

  /// The task that runs the browser session, or `nil`.
  @State private var browserTask: Task<Void, Never>?

  /// The presenter that the card uses when the environment has none.
  @State private var fallbackPresenter = AuthorizationPresenter()

  @Environment(\.authorizationPresenter) private var presenter
  @Environment(\.agentTheme) private var theme
  @Environment(\.editorTheme) private var editorTheme

  /// The report that gets each start and each stop of the browser task, or
  /// `nil`.
  @Environment(\.elicitationBrowserReport) private var reportBrowser

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
      ElicitationHeaderSlot(request: request)
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
    .onExitCommand(perform: didPressEscape)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(Self.identifier)
    .accessibilityFocusTarget(Self.identifier)
    .onDisappear(perform: stopBrowser)
  }

  /// The URL text, and the warning when the host needs one.
  ///
  /// - Parameter url: The URL of the request.
  /// - Returns: The section.
  private func urlSection(_ url: URL) -> some View {
    VStack(alignment: .leading, spacing: theme.spacing.xs) {
      Text(URLDisplay.highlighted(url))
        .font(editorTheme.editorFont)
        .textSelection(.enabled)
        .accessibilityIdentifier(Self.urlIdentifier)
      if let warning = URLDisplay.warning(for: url) {
        Label(warning, systemImage: Self.warningSymbol)
          .font(.callout)
          .foregroundStyle(editorTheme.severityWarning)
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
      Text("Waiting for \(waitingHost) to finish")
        .foregroundStyle(.secondary)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Waiting for \(waitingHost) to finish")
    .accessibilityIdentifier(Self.waitingIdentifier)
  }

  /// The buttons of the current step.
  private var footer: some View {
    HStack(spacing: theme.spacing.s) {
      Spacer()
      switch phase {
      case .idle:
        Button("Cancel", systemImage: Self.cancelSymbol, role: .cancel, action: cancel)
          .accessibilityIdentifier(Self.cancelIdentifier)
        Button("Decline", systemImage: Self.declineSymbol, action: decline)
          .accessibilityIdentifier(Self.declineIdentifier)
        Button("Open in Browser", systemImage: Self.openSymbol, action: open)
          .buttonStyle(.glassProminent)
          .disabled(request.url == nil)
          .accessibilityIdentifier(Self.openIdentifier)
      case .waiting:
        Button("Cancel", systemImage: Self.cancelSymbol, role: .cancel, action: stopWaiting)
          .accessibilityIdentifier(Self.cancelIdentifier)
        Button("Retry", systemImage: Self.retrySymbol, action: openBrowser)
          .buttonStyle(.glassProminent)
          .accessibilityLabel("Open \(ElicitationHeader.agentServer) in the browser again")
          .accessibilityIdentifier(Self.retryIdentifier)
      }
    }
  }

  // MARK: Actions

  /// Opens the browser and sends the consent. The accept moves the request
  /// to `awaitingURLCompletions` of the owner, so the card shows the waiting
  /// state.
  private func open() {
    guard phase == .idle, request.url != nil else { return }
    openBrowser()
    owner.acceptElicitation(request.id, content: nil)
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
    reportBrowser?(.open)
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
    stopBrowser()
    owner.cancelElicitation(request.id)
  }

  /// Stops the browser session of the card and the wait for the
  /// `elicitation/complete` of the agent. The agent gets no message.
  private func stopWaiting() {
    stopBrowser()
    owner.stopWaiting(request.id)
  }

  /// Answers Esc as the Cancel button of the current step does: it stops the
  /// wait in the waiting state, else it cancels the elicitation.
  private func didPressEscape() {
    switch phase {
    case .idle: cancel()
    case .waiting: stopWaiting()
    }
  }

  /// Stops the browser task of the card, when the card has one.
  ///
  /// The card gives ``ElicitationBrowserStep/stop`` to
  /// ``SwiftUI/EnvironmentValues/elicitationBrowserReport`` in the same step
  /// as it stops the task.
  private func stopBrowser() {
    guard let browserTask else { return }
    browserTask.cancel()
    reportBrowser?(.stop)
    self.browserTask = nil
  }
}

/// The host that the kit shows while an accepted URL mode elicitation waits.
extension PendingElicitation {
  /// The host that the waiting state of an accepted URL mode elicitation
  /// names: `targetHost`, or ``ElicitationHeader/agentServer`` when the URL
  /// has no host. ``ElicitationURLConsentView`` and the tool call status of
  /// ``ToolCallView`` show this host.
  var waitingHostName: String {
    targetHost ?? ElicitationHeader.agentServer
  }
}

/// One change of the browser task of an ``ElicitationURLConsentView``.
enum ElicitationBrowserStep: Equatable {
  /// The card started a task that opens a browser session.
  case open

  /// The card stopped its browser task.
  case stop
}

extension EnvironmentValues {
  /// The presenter that opens the browser for a URL mode elicitation, or
  /// `nil` for a presenter that each ``ElicitationURLConsentView`` makes.
  @Entry public var authorizationPresenter: AuthorizationPresenter? = nil

  /// The ``ObservationReport`` that gets each ``ElicitationBrowserStep`` of
  /// the nearest ``ElicitationURLConsentView``, or `nil`.
  ///
  /// The card calls the report in the same step as it starts or stops its
  /// browser task.
  @Entry var elicitationBrowserReport: ObservationReport<ElicitationBrowserStep>? = nil
}
