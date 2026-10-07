import FoundationModelsACPClient
import SwiftUI

/// What the agent does now, for an ``ActivityIndicator`` (plan.md §3.5, §5).
public nonisolated enum ActivityState: Hashable, Sendable {
  /// The agent does not run a turn.
  case idle

  /// The agent runs a turn and no tool call runs.
  case thinking

  /// A tool call runs. The value is the title of the call.
  case runningTool(String)

  /// Finds the state from the values of a session model.
  ///
  /// The value comes from the model at each call, and nothing keeps it.
  /// While `agentState` is not `.running`, the state is ``idle``. While the
  /// agent runs and the transcript has a `ToolCallEntry` with the status
  /// `.inProgress`, the state is ``runningTool(_:)`` with the title of the
  /// last such entry. Otherwise the state is ``thinking``.
  ///
  /// - Parameter session: The session model.
  @MainActor
  public init(session: SessionModel) {
    guard session.isRunning else {
      self = .idle
      return
    }
    let runningCall = session.transcript.lazy.compactMap(\.toolCall).last { $0.status == .inProgress }
    if let runningCall {
      self = .runningTool(ToolCallView.displayTitle(runningCall.shownTitle))
    } else {
      self = .thinking
    }
  }
}

/// A small view that tells what the agent does now (plan.md §5, §9 B).
///
/// - ``ActivityState/thinking`` shows a ``ShimmerView``.
/// - ``ActivityState/runningTool(_:)`` shows a `ProgressView` and the name of
///   the tool.
/// - ``ActivityState/idle`` shows nothing.
///
/// ``init(session:)`` binds the indicator to a `SessionModel`. The body reads
/// `agentState` and the tool call entries of the transcript directly
/// (``ActivityState/init(session:)``), and keeps no copy of them.
public struct ActivityIndicator: View {
  /// The accessibility identifier of the view.
  public static let identifier = "activity-indicator"

  /// The text that a shimmer shows while the agent thinks.
  static var thinkingText: String {
    String(localized: "Thinking…")
  }

  /// The model that gives the state of the indicator.
  enum Source {
    /// A state that the host gives.
    case state(ActivityState)

    /// A session model, which the body reads at each evaluation.
    case session(SessionModel)
  }

  /// The model that gives the state of the indicator.
  let source: Source

  @Environment(\.agentTheme) private var theme

  /// Makes an indicator.
  ///
  /// - Parameter state: The state to show. ``init(session:)`` finds the
  ///   state of a session model.
  public init(state: ActivityState) {
    self.source = .state(state)
  }

  /// Makes the indicator of a session model.
  ///
  /// The indicator shows the title of the last `ToolCallEntry` with the
  /// status `.inProgress` while the agent runs, a shimmer while the agent
  /// runs and no tool call runs, and nothing when `agentState` is not
  /// `.running`.
  ///
  /// - Parameter session: The session model whose state the indicator shows.
  public init(session: SessionModel) {
    self.source = .session(session)
  }

  public var body: some View {
    content
      .contentContainer(identifier: Self.identifier)
  }

  /// The state to show, from the source at this evaluation.
  private var state: ActivityState {
    switch source {
    case .state(let state): state
    case .session(let session): ActivityState(session: session)
    }
  }

  /// The view of the state.
  @ViewBuilder private var content: some View {
    switch state {
    case .idle:
      EmptyView()
    case .thinking:
      ShimmerView(text: Self.thinkingText)
    case .runningTool(let name):
      HStack(spacing: theme.spacing.s) {
        ProgressView()
          .controlSize(.small)
        Text(name)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      .accessibilityElement(children: .combine)
    }
  }
}
