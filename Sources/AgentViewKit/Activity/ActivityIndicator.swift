import SwiftUI

/// What the agent does now, for an ``ActivityIndicator`` (plan.md §3.5, §5).
public nonisolated enum ActivityState: Hashable, Sendable {
  /// The agent does not run a turn.
  case idle

  /// The agent runs a turn and no tool call runs.
  case thinking

  /// A tool call runs. The value is the title of the call.
  case runningTool(String)

  /// Finds the state from a thread (plan.md §3.5).
  ///
  /// When the thread does not run, the state is ``idle``. When a tool call
  /// has the status ``ToolCallStatus/inProgress``, the state is
  /// ``runningTool(_:)`` with the title of the last such call. Otherwise the
  /// state is ``thinking``.
  ///
  /// - Parameter thread: The thread.
  @MainActor
  public init(thread: AgentThread) {
    guard thread.state == .running else {
      self = .idle
      return
    }
    let runningCall = thread.items.last { item in
      guard case .toolCall(let call) = item else { return false }
      return call.status == .inProgress
    }
    if case .toolCall(let call)? = runningCall {
      self = .runningTool(call.title)
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
public struct ActivityIndicator: View {
  /// The accessibility identifier of the view.
  public static let identifier = "activity-indicator"

  /// The text that a shimmer shows while the agent thinks.
  static var thinkingText: String {
    String(localized: "Thinking…")
  }

  /// The state to show.
  let state: ActivityState

  @Environment(\.agentTheme) private var theme

  /// Makes an indicator.
  ///
  /// - Parameter state: The state to show. Use
  ///   ``ActivityState/init(thread:)`` to find it from a thread.
  public init(state: ActivityState) {
    self.state = state
  }

  public var body: some View {
    content
      .contentContainer(identifier: Self.identifier)
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
