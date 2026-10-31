import Foundation
import OSLog
import SwiftUI

/// How far the reload that a Reload button started got.
///
/// The phase names the reload that owns it, so only the newest reload of the
/// current episode writes its outcome: a reload ends in the phase only while
/// the phase is still ``reloading(id:)`` with the id of that reload. A host
/// ends an episode by writing ``idle``, for example when its banner goes away.
/// That write is the whole reset: each reload that is in flight then ends with
/// no effect, and so does the first reload after a second press.
public enum ReloadPhase: Equatable, Sendable {
  /// No reload runs, and the last reload did not fail.
  case idle

  /// A reload runs.
  ///
  /// - Parameter id: The identity of the reload, which no other press shares.
  case reloading(id: UUID)

  /// The last reload failed.
  ///
  /// - Parameter message: The text of its error.
  case failed(String)

  /// Whether a Reload button takes a press in this phase.
  ///
  /// - Parameter isLoading: Whether the model reads its data by another way.
  /// - Returns: `false` while a reload runs or while the model loads.
  public func canReload(isLoading: Bool) -> Bool {
    if case .reloading = self { return false }
    return !isLoading
  }

  /// Moves on to a new reload, which takes the phase from any earlier one.
  ///
  /// - Returns: The identity of the new reload, for ``endReload(_:in:)``.
  mutating func startReload() -> UUID {
    let id = UUID()
    self = .reloading(id: id)
    return id
  }

  /// Writes the outcome of a reload, while the phase is still that reload.
  ///
  /// - Parameters:
  ///   - id: The identity of the reload.
  ///   - outcome: The phase that the reload ended in.
  mutating func endReload(_ id: UUID, in outcome: ReloadPhase) {
    guard self == .reloading(id: id) else { return }
    self = outcome
  }

  /// Runs `reload`, and gives the phase that it ends in.
  ///
  /// - Parameter reload: The work of the reload.
  /// - Returns: ``idle`` when the work ends or is cancelled, and ``failed(_:)``
  ///   with the localized description of the error when it throws.
  public static func outcome(of reload: @MainActor () async throws -> Void) async -> ReloadPhase {
    do {
      try await reload()
      return .idle
    } catch is CancellationError {
      return .idle
    } catch {
      return .failed(error.localizedDescription)
    }
  }
}

/// What a banner of the state of a stream tells: the shape that the banners of
/// AgentViewKit, KanbanViewKit and SnapshotViewKit share.
///
/// The inputs are pure, so a unit test reads the values with no view, and the
/// type knows no model:
///
/// | The stream | The reload | The banner | Symbol and severity |
/// |---|---|---|---|
/// | current | any | none | |
/// | ended clean | not failed | "Updates are missing" | warning |
/// | ended with an error | not failed | "The updates stopped with an error" | failure |
/// | ended | failed | "Updates are still missing" | failure |
///
/// The titles and the text of a failed reload are localized here. What the
/// content lacks depends on the kit, so the kit gives those explanations.
public struct StreamBannerContent: Equatable, Sendable {
  /// The state of a stream.
  public enum Stream: Equatable, Sendable {
    /// The stream is open, and the model has each update.
    case current

    /// The stream ended with no error, so the model can lack updates.
    case endedClean

    /// The stream ended with an error, so the model can lack updates.
    ///
    /// - Parameter message: The text of the error.
    case endedWithError(String)
  }

  /// Which banner the content is, so that a kit can give each one its own
  /// accessibility identifier.
  public enum Kind: Equatable, Sendable {
    /// The stream ended with no error.
    case missedUpdates

    /// The stream ended with an error.
    case streamFailed

    /// The last reload failed.
    case reloadFailed
  }

  /// Which banner the content is.
  public let kind: Kind

  /// The title of the banner.
  public let title: String

  /// The explanation of the banner.
  public let explanation: String

  /// How much the banner asks of the user.
  public let severity: StatusBar.Message.Severity

  /// The SF Symbol name of the banner.
  public let symbolName: String

  /// Makes the content of the state of a stream.
  ///
  /// - Parameters:
  ///   - stream: The state of the stream.
  ///   - reloadPhase: How far the reload of the banner got.
  ///   - missedUpdatesExplanation: The explanation of a stream that ended
  ///     clean, in the words of the kit.
  ///   - streamErrorExplanation: Makes the explanation of a stream that ended
  ///     with an error, from the text of the error. The default is that text.
  /// - Returns: The content, or `nil` for a current stream: the banner does not
  ///   show, and a failed reload shows only while the model lacks updates.
  public init?(
    stream: Stream, reloadPhase: ReloadPhase, missedUpdatesExplanation: String,
    streamErrorExplanation: (String) -> String = { $0 }
  ) {
    switch stream {
    case .current:
      return nil
    case .endedClean:
      self.init(
        streamError: nil, reloadPhase: reloadPhase, missedUpdatesExplanation: missedUpdatesExplanation,
        streamErrorExplanation: streamErrorExplanation)
    case .endedWithError(let error):
      self.init(
        streamError: error, reloadPhase: reloadPhase, missedUpdatesExplanation: missedUpdatesExplanation,
        streamErrorExplanation: streamErrorExplanation)
    }
  }

  /// Makes the content of a stream that ended, for a kit that knows that the
  /// banner shows.
  ///
  /// - Parameters:
  ///   - streamError: The text of the error that ended the stream, or `nil`
  ///     for a clean end.
  ///   - reloadPhase: How far the reload of the banner got.
  ///   - missedUpdatesExplanation: The explanation of a stream that ended
  ///     clean, in the words of the kit.
  ///   - streamErrorExplanation: Makes the explanation of a stream that ended
  ///     with an error, from the text of the error. The default is that text.
  public init(
    streamError: String?, reloadPhase: ReloadPhase, missedUpdatesExplanation: String,
    streamErrorExplanation: (String) -> String = { $0 }
  ) {
    if case .failed(let error) = reloadPhase {
      kind = .reloadFailed
      title = String(localized: "Updates are still missing", bundle: .module)
      explanation = String(localized: "The reload failed: \(error)", bundle: .module)
      severity = .failure
      symbolName = SharedSymbol.error
    } else if let streamError {
      kind = .streamFailed
      title = String(localized: "The updates stopped with an error", bundle: .module)
      explanation = streamErrorExplanation(streamError)
      severity = .failure
      symbolName = SharedSymbol.error
    } else {
      kind = .missedUpdates
      title = String(localized: "Updates are missing", bundle: .module)
      explanation = missedUpdatesExplanation
      severity = .warning
      symbolName = SharedSymbol.warning
    }
  }

  /// The text of the ``StatusBar`` of the banner.
  ///
  /// - Parameter identifier: The accessibility identifier of the text.
  /// - Returns: The message.
  public func message(identifier: String) -> StatusBar.Message {
    StatusBar.Message(
      title: title, explanation: explanation, symbolName: symbolName, identifier: identifier, severity: severity)
  }
}

extension StatusBar.Action {
  /// The log of a reload that failed with no phase to record it.
  private static let logger = Logger(subsystem: "AgentViewKitStyle", category: "StatusBar")

  /// Makes the Reload button of a bar, with the one title, hint and symbol of a
  /// reload.
  ///
  /// A press runs `perform` at once, up to its first suspension, so the host
  /// sees the start of the reload in the step of the press. The work ends on
  /// its own: it does not stop when the bar goes away.
  ///
  /// - Parameters:
  ///   - identifier: The accessibility identifier of the button.
  ///   - isEnabled: Whether the button takes a press. Read it from
  ///     ``ReloadPhase/canReload(isLoading:)``: the button is off while a
  ///     reload runs or the model loads.
  ///   - phase: The phase of the host, which the reload moves on and in which
  ///     a thrown error lands, or `nil` for a host that records its own state:
  ///     then a thrown error only goes to the log. The outcome lands only while
  ///     the phase is still this reload, so the host writes
  ///     ``ReloadPhase/idle`` to drop each reload in flight.
  ///   - perform: The work of the reload.
  /// - Returns: The button, with the ``SharedSymbol/reload`` symbol.
  public static func reload(
    identifier: String, isEnabled: Bool, phase: Binding<ReloadPhase>? = nil,
    perform: @escaping @MainActor () async throws -> Void
  ) -> StatusBar.Action {
    StatusBar.Action(
      title: String(localized: "Reload", bundle: .module), systemImage: SharedSymbol.reload, identifier: identifier,
      isEnabled: isEnabled, hint: String(localized: "Reads the latest state again.", bundle: .module)
    ) {
      guard let phase else {
        Task.immediate { await logFailure(of: perform) }
        return
      }
      let id = phase.wrappedValue.startReload()
      Task.immediate { await finishReload(id, perform, recordingIn: phase) }
    }
  }

  /// Runs the work of a reload and records the phase that it ends in.
  ///
  /// - Parameters:
  ///   - id: The identity of the reload.
  ///   - perform: The work of the reload.
  ///   - phase: The phase of the host.
  private static func finishReload(
    _ id: UUID, _ perform: @MainActor () async throws -> Void, recordingIn phase: Binding<ReloadPhase>
  ) async {
    let outcome = await ReloadPhase.outcome(of: perform)
    phase.wrappedValue.endReload(id, in: outcome)
  }

  /// Runs the work of a reload for a host with no phase, and logs a failure.
  ///
  /// - Parameter perform: The work of the reload.
  private static func logFailure(of perform: @MainActor () async throws -> Void) async {
    guard case .failed(let message) = await ReloadPhase.outcome(of: perform) else { return }
    logger.error("A reload failed with no phase to record it: \(message, privacy: .public)")
  }
}
