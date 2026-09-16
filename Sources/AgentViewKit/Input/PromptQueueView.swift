import SwiftUI

/// The list of the messages that wait while the thread runs a turn
/// (plan.md §9 D).
///
/// Put the view above ``PromptInputView``, and give the same queue to the
/// composer with ``SwiftUI/View/promptQueue(_:)``:
///
/// ```swift
/// VStack {
///   PromptQueueView(queue: queue)
///   PromptInputView(text: $draft) {}
/// }
/// .promptQueue(queue)
/// ```
///
/// The view shows a count badge and one row for each item. A drag reorders
/// the rows. Each row has a text field for an inline edit, a "send now"
/// button that sends the item at once through
/// ``AgentThreadActions/send(_:)``, and a remove button. The view is hidden
/// while the queue is empty.
public struct PromptQueueView: View {
  /// The accessibility identifier of the view.
  public static let identifier = "prompt-queue"

  /// The accessibility identifier of the count badge.
  public static let countIdentifier = "prompt-queue-count"

  /// The queue that the view shows and changes.
  let queue: PromptQueue

  @Environment(\.threadActions) private var actions
  @Environment(\.agentTheme) private var theme

  /// Makes the view.
  ///
  /// - Parameter queue: The queue that the view shows and changes.
  public init(queue: PromptQueue) {
    self.queue = queue
  }

  /// The accessibility identifier of the text field of an item.
  ///
  /// - Parameter id: The identifier of the item.
  /// - Returns: The accessibility identifier.
  public static func editIdentifier(_ id: QueuedPromptID) -> String {
    "prompt-queue-edit-\(id.rawValue)"
  }

  /// The accessibility identifier of the "send now" button of an item.
  ///
  /// - Parameter id: The identifier of the item.
  /// - Returns: The accessibility identifier.
  public static func sendNowIdentifier(_ id: QueuedPromptID) -> String {
    "prompt-queue-send-now-\(id.rawValue)"
  }

  /// The accessibility identifier of the remove button of an item.
  ///
  /// - Parameter id: The identifier of the item.
  /// - Returns: The accessibility identifier.
  public static func removeIdentifier(_ id: QueuedPromptID) -> String {
    "prompt-queue-remove-\(id.rawValue)"
  }

  /// The accessibility label of the count badge.
  ///
  /// - Parameter count: The number of queued items.
  /// - Returns: The label.
  static func countLabel(_ count: Int) -> String {
    String(localized: "\(count) queued")
  }

  public var body: some View {
    if !queue.isEmpty {
      VStack(alignment: .leading, spacing: theme.spacing.xs) {
        header
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
          ForEach(queue.items) { item in
            row(for: item.id)
          }
          .reorderable()
        }
        .reorderContainer(for: QueuedPrompt.self) { difference in
          queue.move(difference.sources, to: difference.destination.position)
        }
      }
      .padding(theme.spacing.s)
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier(Self.identifier)
    }
  }

  /// The title and the count badge.
  private var header: some View {
    HStack(spacing: theme.spacing.xs) {
      Label(String(localized: "Queued"), systemImage: "text.line.first.and.arrowtriangle.forward")
        .font(.caption)
        .fontWeight(theme.symbolWeight)
        .foregroundStyle(.secondary)
      Text(queue.count, format: .number)
        .font(.caption2.monospacedDigit())
        .padding(.horizontal, theme.spacing.xs)
        .background(.fill.secondary, in: Capsule())
        .accessibilityLabel(Self.countLabel(queue.count))
        .accessibilityIdentifier(Self.countIdentifier)
    }
  }

  /// The row of one item.
  ///
  /// - Parameter id: The identifier of the item.
  /// - Returns: The row.
  private func row(for id: QueuedPromptID) -> some View {
    HStack(spacing: theme.spacing.xs) {
      Image(systemName: "line.3.horizontal")
        .foregroundStyle(.tertiary)
        .accessibilityHidden(true)
      TextField(String(localized: "Queued message"), text: text(of: id), axis: .vertical)
        .textFieldStyle(.plain)
        .font(theme.proseFont)
        .lineLimit(1...3)
        .accessibilityIdentifier(Self.editIdentifier(id))
      Button {
        sendNow(id)
      } label: {
        Label(String(localized: "Send now"), systemImage: "arrow.up.circle")
          .labelStyle(.iconOnly)
      }
      .help(String(localized: "Send this message now"))
      .accessibilityIdentifier(Self.sendNowIdentifier(id))
      Button {
        queue.remove(id)
      } label: {
        Label(String(localized: "Remove"), systemImage: "xmark")
          .labelStyle(.iconOnly)
      }
      .help(String(localized: "Remove this message from the queue"))
      .accessibilityIdentifier(Self.removeIdentifier(id))
    }
    .buttonStyle(.borderless)
    .fontWeight(theme.symbolWeight)
    .padding(.horizontal, theme.spacing.s)
    .padding(.vertical, theme.spacing.xs)
    .background(.fill.tertiary, in: .rect(cornerRadius: theme.radii.s))
  }

  /// A binding to the text of an item.
  ///
  /// - Parameter id: The identifier of the item.
  /// - Returns: The binding. It reads an empty text when no item has `id`.
  private func text(of id: QueuedPromptID) -> Binding<String> {
    Binding {
      queue.items.first { $0.id == id }?.input.text ?? ""
    } set: { text in
      queue.update(id, text: text)
    }
  }

  /// Removes an item and sends it at once.
  ///
  /// - Parameter id: The identifier of the item.
  private func sendNow(_ id: QueuedPromptID) {
    guard let input = queue.take(id) else { return }
    let actions = actions
    Task { await actions.send(input) }
  }
}
