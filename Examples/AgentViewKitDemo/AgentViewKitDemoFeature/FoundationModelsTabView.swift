import AgentViewKit
import AgentViewKitFoundationModels
import SwiftUI

/// The FoundationModels tab of the demo app.
///
/// The tab binds the session of the launch options
/// (``FoundationModelsDemoSession``) and shows:
///
/// - the ``StateBanner``, the ``AgentThreadView``, and the
///   ``ContextUsageView`` of the bound thread,
/// - a ``PromptInputView``,
/// - the ``ActivityTimeline`` of the thread, in a trailing column.
///
/// When the model is not available, the tab shows the reason and no
/// composer.
struct FoundationModelsTabView: View {
  /// The accessibility identifier of the text that says why the model is
  /// not available.
  static let unavailableIdentifier = "demo-foundation-models-unavailable"

  /// The width of the activity timeline column.
  static let timelineWidth: CGFloat = 300

  /// The session of the tab.
  @State private var session: FoundationModelsDemoSession

  /// The text of the composer.
  @State private var draft = AttributedString()

  /// Makes the tab.
  ///
  /// - Parameter options: The launch options of the app.
  init(options: DemoLaunchOptions) {
    _session = State(initialValue: FoundationModelsDemoSession(options: options))
  }

  var body: some View {
    switch session.state {
    case .available(let actions):
      boundThread(actions: actions)
    case .unavailable(let reason):
      unavailableView(reason: reason)
    }
  }

  /// The bound thread with its status views and the composer, and the
  /// activity timeline of the thread.
  ///
  /// - Parameter actions: The actions of the bound session.
  /// - Returns: The view of the thread.
  private func boundThread(actions: SessionThreadActions) -> some View {
    let thread = actions.source.thread
    return HStack(spacing: 0) {
      VStack(spacing: 0) {
        StateBanner(state: thread.state)
        AgentThreadView(thread: thread, actions: actions)
        ContextUsageView(usage: thread.usage)
          .frame(maxWidth: .infinity, alignment: .trailing)
          .padding(.horizontal)
        PromptInputView(text: $draft) {}
          .padding()
      }
      Divider()
      ActivityTimeline(thread: thread)
        .frame(width: Self.timelineWidth)
    }
    .environment(\.agentThread, thread)
    .environment(\.threadActions, actions)
  }

  /// The view of a model that is not available.
  ///
  /// - Parameter reason: The text that says why.
  /// - Returns: The view.
  private func unavailableView(reason: String) -> some View {
    ContentUnavailableView {
      Label("Model Unavailable", systemImage: "exclamationmark.triangle")
    } description: {
      Text(reason)
        .accessibilityIdentifier(Self.unavailableIdentifier)
    }
  }
}
