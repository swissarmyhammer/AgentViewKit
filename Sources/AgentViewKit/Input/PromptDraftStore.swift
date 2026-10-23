import Foundation
import FoundationModelsACPClient
import Observation

/// The unsent text of the prompt of one session.
///
/// The draft is a reference that ``DefaultThreadComposer`` reads and writes
/// through its text binding, so a new composer view of the same session reads
/// the text that an earlier view of the session wrote.
@MainActor @Observable final class PromptDraft {
  /// The text of the prompt.
  var text = AttributedString()
}

/// The drafts of ``DefaultThreadComposer``, one for each session model
/// (^f41brfh).
///
/// A host can rebuild the thread view of a session, for example when it moves
/// the view to another column. The composer view then goes away with its
/// state, so the draft lives here, keyed by the session model, and not in the
/// view. A draft lives as long as its session model: the store holds the
/// model weakly, and drops the drafts of gone models when it adds a draft.
@MainActor final class PromptDraftStore {
  /// The draft of one session model.
  private struct Entry {
    /// The session model of the draft, or `nil` when the model went away.
    weak var session: SessionModel?

    /// The draft of the session.
    let draft: PromptDraft
  }

  /// The store of the kit.
  static let shared = PromptDraftStore()

  /// The drafts, keyed by the identity of their session model.
  private var entries: [ObjectIdentifier: Entry] = [:]

  /// The draft of `session`. The first call for a session model makes an
  /// empty draft; each later call gives the same draft.
  ///
  /// - Parameter session: The session model of the composer.
  /// - Returns: The draft of the session.
  func draft(for session: SessionModel) -> PromptDraft {
    let key = ObjectIdentifier(session)
    // A gone model can leave its identifier to a new model, so the entry
    // counts only when it still holds this model.
    if let entry = entries[key], entry.session === session {
      return entry.draft
    }
    let draft = PromptDraft()
    entries = entries.filter { $0.value.session != nil }
    entries[key] = Entry(session: session, draft: draft)
    return draft
  }
}
