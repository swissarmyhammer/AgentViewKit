import FoundationModelsACP
import FoundationModelsACPClient
import OSLog
import SwiftUI

/// The card of one pending elicitation of a client model (plan.md §3.2
/// "Pending requests", §13.2, §13.3).
///
/// The card is an ``ElicitationView`` for a form mode request, or an
/// ``ElicitationURLConsentView`` for a URL mode request.
/// ``RequestDeck`` shows one card for each pending elicitation of a
/// client model. The deck is the only place that shows the card:
/// ``ToolCallView`` shows only a "Waiting for your answer" status for an
/// elicitation that is linked to its tool call. Each card sends the answer of
/// the user to the reply methods of the model that holds the elicitation.
///
/// The card does not move the focus and does not announce when it appears.
/// The ``RequestDeck`` announces each new request, and moves the focus only
/// when the front request leaves the deck or when the user brings a request
/// to the front.
struct ElicitationCard: View {
  /// The log of an elicitation that the kit cannot show.
  private static let logger = Logger(subsystem: "AgentViewKit", category: "ElicitationCard")

  /// The pending elicitation to show.
  let request: PendingElicitation

  /// The model that holds the elicitation.
  let owner: any PendingElicitationOwner

  /// Tells if the kit has a card for the mode of a pending elicitation.
  ///
  /// The ACP schema tells a client not to show a mode that it does not know
  /// as a known mode. The hosts show no card for such a mode, and the log
  /// records it. The elicitation stays pending in the model.
  ///
  /// - Parameter pending: The pending elicitation.
  /// - Returns: `true` for the form mode and the URL mode.
  static func hasCard(for pending: PendingElicitation) -> Bool {
    switch pending.request.mode {
    case .form, .url:
      return true
    case .unknown(let kind, _):
      logger.error("The elicitation mode \(kind, privacy: .public) is not known. The kit shows no card.")
      return false
    }
  }

  var body: some View {
    switch request.request.mode {
    case .form:
      ElicitationView(request: request, owner: owner)
    case .url:
      ElicitationURLConsentView(request: request, owner: owner)
    case .unknown:
      EmptyView()
    }
  }
}

// MARK: - Previews

/// One pending elicitation of the previews, in its card in one place.
///
/// The preview session holds the elicitation and records the answer of the
/// card, so a press in the canvas reaches no agent and no network.
private struct ElicitationCardSample: View {
  /// The place of the card (``RequestDeckPlace``).
  enum Place {
    /// Alone in content: the actions keep the glass styles.
    case content

    /// In the request deck in the bottom bar of a thread, over a transcript
    /// that scrolls under the bar: the deck is on glass.
    case bottomBar

    /// The transcript of the session of the sample.
    var transcript: [PreviewTranscriptItem] {
      switch self {
      case .content: []
      case .bottomBar: PreviewFixtures.scrolledTranscript
      }
    }
  }

  /// The place of the card.
  let place: Place

  /// The preview session that holds the elicitation.
  @State private var session: SessionModel

  /// Makes the sample of one elicitation.
  ///
  /// - Parameters:
  ///   - request: The pending elicitation.
  ///   - place: The place of the card.
  init(_ request: CreateElicitationRequest, in place: Place = .content) {
    self.place = place
    _session = State(
      initialValue: PreviewFixtures.elicitationCardSession(asking: request, transcript: place.transcript))
  }

  var body: some View {
    switch place {
    case .content:
      if let request = session.pendingElicitations.first {
        ElicitationCard(request: request, owner: session)
          .padding()
      }
    case .bottomBar:
      AgentThreadView(session: session) {
        RequestDeck(session: session)
        DefaultThreadComposer()
      }
    }
  }
}

#Preview("Form with a field of each kind") {
  ElicitationCardSample(PreviewFixtures.eachKindFormElicitation)
}

#Preview("Form with a field that is not valid") {
  ElicitationCardSample(PreviewFixtures.invalidFieldElicitation)
}

#Preview("In content, before the user types: the required field shows no error yet") {
  ElicitationCardSample(PreviewFixtures.formElicitation)
}

#Preview("URL consent request") {
  ElicitationCardSample(PreviewFixtures.urlElicitation)
}

#Preview("In the request deck in the bottom bar of a thread") {
  ElicitationCardSample(PreviewFixtures.formElicitation, in: .bottomBar)
}
