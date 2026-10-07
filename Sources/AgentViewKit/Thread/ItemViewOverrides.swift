import FoundationModelsACPClient
import SwiftUI

/// A function that makes the view of one transcript entry (plan.md §3.6).
///
/// The function gets the observable entry object of its case, such as a
/// `ToolCallEntry`. The view that it makes reads the values of the model
/// directly, so a change to the entry changes the view with no other step.
public typealias ItemViewRenderer<Entry> = @MainActor (Entry) -> AnyView

/// The item view overrides of the environment (plan.md §3.6, §7).
///
/// Each `TranscriptEntry` case has one environment key. Thus a change to the
/// override of one case does not change the views that read a different
/// case. Set an override with the typed modifier of its case, such as
/// ``SwiftUI/View/toolCallView(_:)``. A key with no override is `nil`, and
/// the row then shows the default view of the case. See ``ItemRow``.
extension EnvironmentValues {
  /// The override of the view of a `UserMessageEntry`.
  @Entry public var userMessageViewOverride: ItemViewRenderer<UserMessageEntry>? = nil

  /// The override of the view of an `AgentMessageEntry`.
  @Entry public var assistantMessageViewOverride: ItemViewRenderer<AgentMessageEntry>? = nil

  /// The override of the view of a `ThoughtEntry`.
  @Entry public var reasoningViewOverride: ItemViewRenderer<ThoughtEntry>? = nil

  /// The override of the view of a `ToolCallEntry`.
  @Entry public var toolCallViewOverride: ItemViewRenderer<ToolCallEntry>? = nil

  /// The override of the view of a `TerminalEntry`.
  @Entry public var terminalViewOverride: ItemViewRenderer<TerminalEntry>? = nil

  /// The override of the view of a `PlanTranscriptEntry`.
  @Entry public var planViewOverride: ItemViewRenderer<PlanTranscriptEntry>? = nil

  /// The override of the view of an `ErrorEntry`.
  @Entry public var errorViewOverride: ItemViewRenderer<ErrorEntry>? = nil

  /// The override of the view of an `UnknownEntry`.
  @Entry public var unknownItemViewOverride: ItemViewRenderer<UnknownEntry>? = nil

  /// The override of the view of a `CompactionEntry`.
  @Entry public var compactionEntryViewOverride: ItemViewRenderer<CompactionEntry>? = nil
}

extension View {
  /// Replaces the view of each user message entry in this view.
  ///
  /// - Parameter content: The function that makes the view of an entry.
  /// - Returns: A view that gives the override to its subtree.
  public func userMessageView<Content: View>(
    @ViewBuilder _ content: @escaping @MainActor (UserMessageEntry) -> Content
  ) -> some View {
    itemViewOverride(\.userMessageViewOverride, content)
  }

  /// Replaces the view of each agent message entry in this view.
  ///
  /// - Parameter content: The function that makes the view of an entry.
  /// - Returns: A view that gives the override to its subtree.
  public func assistantMessageView<Content: View>(
    @ViewBuilder _ content: @escaping @MainActor (AgentMessageEntry) -> Content
  ) -> some View {
    itemViewOverride(\.assistantMessageViewOverride, content)
  }

  /// Replaces the view of each thought entry in this view.
  ///
  /// - Parameter content: The function that makes the view of an entry.
  /// - Returns: A view that gives the override to its subtree.
  public func reasoningView<Content: View>(
    @ViewBuilder _ content: @escaping @MainActor (ThoughtEntry) -> Content
  ) -> some View {
    itemViewOverride(\.reasoningViewOverride, content)
  }

  /// Replaces the view of each tool call entry in this view.
  ///
  /// The override replaces the whole row of the call. To replace only the
  /// expanded body of the calls of one tool, use
  /// ``SwiftUI/View/toolCallView(named:_:)``.
  ///
  /// - Parameter content: The function that makes the view of an entry.
  /// - Returns: A view that gives the override to its subtree.
  public func toolCallView<Content: View>(
    @ViewBuilder _ content: @escaping @MainActor (ToolCallEntry) -> Content
  ) -> some View {
    itemViewOverride(\.toolCallViewOverride, content)
  }

  /// Replaces the view of each terminal entry in this view.
  ///
  /// - Parameter content: The function that makes the view of an entry.
  /// - Returns: A view that gives the override to its subtree.
  public func terminalView<Content: View>(
    @ViewBuilder _ content: @escaping @MainActor (TerminalEntry) -> Content
  ) -> some View {
    itemViewOverride(\.terminalViewOverride, content)
  }

  /// Replaces the view of each plan entry in this view.
  ///
  /// - Parameter content: The function that makes the view of an entry.
  /// - Returns: A view that gives the override to its subtree.
  public func planView<Content: View>(
    @ViewBuilder _ content: @escaping @MainActor (PlanTranscriptEntry) -> Content
  ) -> some View {
    itemViewOverride(\.planViewOverride, content)
  }

  /// Replaces the view of each error entry in this view.
  ///
  /// - Parameter content: The function that makes the view of an entry.
  /// - Returns: A view that gives the override to its subtree.
  public func errorView<Content: View>(
    @ViewBuilder _ content: @escaping @MainActor (ErrorEntry) -> Content
  ) -> some View {
    itemViewOverride(\.errorViewOverride, content)
  }

  /// Replaces the view of each unknown entry in this view.
  ///
  /// - Parameter content: The function that makes the view of an entry.
  /// - Returns: A view that gives the override to its subtree.
  public func unknownItemView<Content: View>(
    @ViewBuilder _ content: @escaping @MainActor (UnknownEntry) -> Content
  ) -> some View {
    itemViewOverride(\.unknownItemViewOverride, content)
  }

  /// Replaces the view of each compaction entry in this view.
  ///
  /// - Parameter content: The function that makes the view of an entry.
  /// - Returns: A view that gives the override to its subtree.
  public func compactionEntryView<Content: View>(
    @ViewBuilder _ content: @escaping @MainActor (CompactionEntry) -> Content
  ) -> some View {
    itemViewOverride(\.compactionEntryViewOverride, content)
  }

  /// Sets one item view override for this view and each view in it.
  ///
  /// - Parameters:
  ///   - key: The environment key of the entry case.
  ///   - content: The function that makes the view of an entry.
  /// - Returns: A view that gives the override to its subtree.
  private func itemViewOverride<Entry, Content: View>(
    _ key: WritableKeyPath<EnvironmentValues, ItemViewRenderer<Entry>?>,
    _ content: @escaping @MainActor (Entry) -> Content
  ) -> some View {
    environment(key) { entry in AnyView(content(entry)) }
  }
}
