import SwiftUI

/// A function that makes the view of one thread item (plan.md §3.6).
///
/// The function gets the concrete record of the item.
public typealias ItemViewRenderer<Record> = @MainActor (Record) -> AnyView

/// The item view overrides of the environment (plan.md §3.6, §7).
///
/// Each ``ThreadItem`` kind has one environment key. Thus a change to the
/// override of one kind does not change the views that read a different
/// kind. Set an override with the typed modifier of its kind, such as
/// ``SwiftUI/View/toolCallView(_:)``. A key with no override is `nil`, and
/// the thread view then shows the default view of the kind.
extension EnvironmentValues {
  /// The override of the ``ThreadItem/system(_:)`` view.
  @Entry public var systemPromptViewOverride: ItemViewRenderer<SystemPrompt>? = nil

  /// The override of the ``ThreadItem/userMessage(_:)`` view.
  @Entry public var userMessageViewOverride: ItemViewRenderer<Message>? = nil

  /// The override of the ``ThreadItem/assistantMessage(_:)`` view.
  @Entry public var assistantMessageViewOverride: ItemViewRenderer<Message>? = nil

  /// The override of the ``ThreadItem/reasoning(_:)`` view.
  @Entry public var reasoningViewOverride: ItemViewRenderer<Reasoning>? = nil

  /// The override of the ``ThreadItem/toolCall(_:)`` view.
  @Entry public var toolCallViewOverride: ItemViewRenderer<ToolCallRecord>? = nil

  /// The override of the ``ThreadItem/structured(_:)`` view.
  ///
  /// This override replaces the view of each structured item. To replace the
  /// view of one schema name only, use
  /// ``SwiftUI/View/structuredItem(_:_:)``.
  @Entry public var structuredItemViewOverride: ItemViewRenderer<StructuredRecord>? = nil

  /// The override of the ``ThreadItem/compaction(_:)`` view.
  @Entry public var compactionViewOverride: ItemViewRenderer<CompactionMarker>? = nil

  /// The override of the ``ThreadItem/error(_:)`` view.
  @Entry public var errorViewOverride: ItemViewRenderer<ThreadError>? = nil

  /// The override of the ``ThreadItem/unknown(_:)`` view.
  @Entry public var unknownItemViewOverride: ItemViewRenderer<UnknownRecord>? = nil
}

extension View {
  /// Replaces the view of each system prompt item in this view.
  ///
  /// - Parameter content: The function that makes the view of a record.
  /// - Returns: A view that gives the override to its subtree.
  public func systemPromptView<Content: View>(
    @ViewBuilder _ content: @escaping @MainActor (SystemPrompt) -> Content
  ) -> some View {
    itemViewOverride(\.systemPromptViewOverride, content)
  }

  /// Replaces the view of each user message item in this view.
  ///
  /// - Parameter content: The function that makes the view of a record.
  /// - Returns: A view that gives the override to its subtree.
  public func userMessageView<Content: View>(
    @ViewBuilder _ content: @escaping @MainActor (Message) -> Content
  ) -> some View {
    itemViewOverride(\.userMessageViewOverride, content)
  }

  /// Replaces the view of each assistant message item in this view.
  ///
  /// - Parameter content: The function that makes the view of a record.
  /// - Returns: A view that gives the override to its subtree.
  public func assistantMessageView<Content: View>(
    @ViewBuilder _ content: @escaping @MainActor (Message) -> Content
  ) -> some View {
    itemViewOverride(\.assistantMessageViewOverride, content)
  }

  /// Replaces the view of each reasoning item in this view.
  ///
  /// - Parameter content: The function that makes the view of a record.
  /// - Returns: A view that gives the override to its subtree.
  public func reasoningView<Content: View>(
    @ViewBuilder _ content: @escaping @MainActor (Reasoning) -> Content
  ) -> some View {
    itemViewOverride(\.reasoningViewOverride, content)
  }

  /// Replaces the view of each tool call item in this view.
  ///
  /// - Parameter content: The function that makes the view of a record.
  /// - Returns: A view that gives the override to its subtree.
  public func toolCallView<Content: View>(
    @ViewBuilder _ content: @escaping @MainActor (ToolCallRecord) -> Content
  ) -> some View {
    itemViewOverride(\.toolCallViewOverride, content)
  }

  /// Replaces the view of each structured item in this view.
  ///
  /// - Parameter content: The function that makes the view of a record.
  /// - Returns: A view that gives the override to its subtree.
  public func structuredItemView<Content: View>(
    @ViewBuilder _ content: @escaping @MainActor (StructuredRecord) -> Content
  ) -> some View {
    itemViewOverride(\.structuredItemViewOverride, content)
  }

  /// Replaces the view of each compaction item in this view.
  ///
  /// - Parameter content: The function that makes the view of a record.
  /// - Returns: A view that gives the override to its subtree.
  public func compactionView<Content: View>(
    @ViewBuilder _ content: @escaping @MainActor (CompactionMarker) -> Content
  ) -> some View {
    itemViewOverride(\.compactionViewOverride, content)
  }

  /// Replaces the view of each error item in this view.
  ///
  /// - Parameter content: The function that makes the view of a record.
  /// - Returns: A view that gives the override to its subtree.
  public func errorView<Content: View>(
    @ViewBuilder _ content: @escaping @MainActor (ThreadError) -> Content
  ) -> some View {
    itemViewOverride(\.errorViewOverride, content)
  }

  /// Replaces the view of each unknown item in this view.
  ///
  /// - Parameter content: The function that makes the view of a record.
  /// - Returns: A view that gives the override to its subtree.
  public func unknownItemView<Content: View>(
    @ViewBuilder _ content: @escaping @MainActor (UnknownRecord) -> Content
  ) -> some View {
    itemViewOverride(\.unknownItemViewOverride, content)
  }

  /// Sets one item view override for this view and each view in it.
  ///
  /// - Parameters:
  ///   - key: The environment key of the item kind.
  ///   - content: The function that makes the view of a record.
  /// - Returns: A view that gives the override to its subtree.
  private func itemViewOverride<Record, Content: View>(
    _ key: WritableKeyPath<EnvironmentValues, ItemViewRenderer<Record>?>,
    _ content: @escaping @MainActor (Record) -> Content
  ) -> some View {
    environment(key) { record in AnyView(content(record)) }
  }
}
