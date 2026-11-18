import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// The side of a message where a fork cuts the history (D205).
public enum ForkSide: Sendable, Hashable {
  /// The fork gets the history up to the message, and the message too. This
  /// is the side of an agent message.
  case after

  /// The fork gets the history up to the message, but not the message. This
  /// is the side of a user message: the composer of the fork gets its text.
  case before
}

/// The message that ``AgentCommandVerb/forkFromHere`` gives to the fork
/// action of the host (D205).
///
/// The host makes the fork. The kit does not change a session.
public struct ForkFromHereRequest: Sendable, Hashable {
  /// The `MessageId` of the message where the fork cuts the history.
  public let messageId: MessageId

  /// The side of the message where the fork cuts the history: ``ForkSide/after``
  /// for an agent message, ``ForkSide/before`` for a user message.
  public let side: ForkSide

  /// The text of the user message, as Markdown, for the composer of the
  /// fork. It is `nil` for ``ForkSide/after``.
  public let text: String?

  /// Makes a request.
  ///
  /// - Parameters:
  ///   - messageId: The `MessageId` of the message.
  ///   - side: The side of the message where the fork cuts the history.
  ///   - text: The text of the user message for ``ForkSide/before``, or
  ///     `nil`.
  public init(messageId: MessageId, side: ForkSide, text: String?) {
    self.messageId = messageId
    self.side = side
    self.text = text
  }

  /// Makes the request of a message entry: ``ForkSide/after`` for an agent
  /// message, and ``ForkSide/before`` with the Markdown of the message
  /// (`ThreadExporter.markdown(for:)`) for a user message.
  ///
  /// - Parameter entry: The message entry.
  /// - Returns: The request, or `nil` when the entry has no `MessageId` yet.
  @MainActor init?(entry: MessageEntry) {
    guard let messageId = entry.messageId else { return nil }
    switch entry {
    case .agent: self.init(messageId: messageId, side: .after, text: nil)
    case .user(let user):
      self.init(messageId: messageId, side: .before, text: ThreadExporter.markdown(for: user.content))
    }
  }
}

/// The fork action that the host gives with
/// ``SwiftUI/View/onForkFromHere(unavailableReason:_:)``.
struct ForkFromHereAction {
  /// The reason that the host cannot fork now, or `nil` when it can.
  let unavailableReason: String?

  /// Makes the fork of a request.
  let perform: @MainActor (ForkFromHereRequest) -> Void

  /// The reason when the agent gave no `MessageId` for a message yet.
  static var noMessageIDReason: String {
    String(localized: "The agent has no ID for this message yet.", bundle: .module)
  }

  /// The reason that Fork from Here cannot run on `entry`, or `nil` when it
  /// can.
  ///
  /// The reason of the host comes first. Then a message with no `MessageId`
  /// cannot fork.
  ///
  /// - Parameter entry: The message entry, or `nil` when no message is
  ///   known.
  /// - Returns: The reason, or `nil`.
  @MainActor func unavailableReason(for entry: MessageEntry?) -> String? {
    if let unavailableReason { return unavailableReason }
    guard let entry, entry.messageId == nil else { return nil }
    return Self.noMessageIDReason
  }
}

extension EnvironmentValues {
  /// The fork action of the host, or `nil` when the host gives none. The
  /// value is `nil` until a view sets it with
  /// ``SwiftUI/View/onForkFromHere(unavailableReason:_:)``.
  @Entry var forkFromHere: ForkFromHereAction? = nil
}

extension View {
  /// Gives the fork action of the host to Fork from Here
  /// (``AgentCommandVerb/forkFromHere``) in this view (D205).
  ///
  /// With no action, the verb is not in the registry, and the message
  /// actions show no fork button. With an action, the verb is in the
  /// registry, the Session menu and the context menu of a message, and
  /// ``MessageActions`` shows the fork button after Export. The verb acts on
  /// one message: the message of the payload, of the context menu, or of the
  /// selection. An agent message gives ``ForkSide/after``. A user message
  /// gives ``ForkSide/before`` and its text. A message with no `MessageId` is
  /// disabled.
  ///
  /// Apply the modifier outside the agent command scope, as
  /// ``SwiftUI/View/agentCommandGroups(off:)``:
  ///
  /// ```swift
  /// AgentThreadView(session: session)
  ///   .messageFooter { entry in MessageActions(entry: entry) }
  ///   .onForkFromHere { request in host.fork(session, from: request) }
  /// ```
  ///
  /// - Parameters:
  ///   - unavailableReason: The reason that the host cannot fork now, such
  ///     as "This agent cannot fork a session.", or `nil` when it can. With a
  ///     reason, the verb is disabled with that reason.
  ///   - perform: Makes the fork of the request.
  /// - Returns: A view that gives the fork action to the views in it.
  public func onForkFromHere(
    unavailableReason: String? = nil, _ perform: @escaping @MainActor (ForkFromHereRequest) -> Void
  ) -> some View {
    environment(\.forkFromHere, ForkFromHereAction(unavailableReason: unavailableReason, perform: perform))
  }
}
