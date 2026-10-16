import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import Foundation
import Observation
import SwiftUI
import Testing

/// The guarantee "settled paragraphs are not evaluated again" (plan.md §8,
/// research R1).
///
/// ``BodyEvaluationCounter`` exists only in debug builds. These tests
/// count the body evaluations of each ``ParagraphView`` in a hosted
/// ``ResponseView`` while its Markdown text grows one chunk after the other,
/// as the text of a transcript entry grows.
///
/// The tests do not turn the run loop and do not suspend. Each change of the
/// text has exactly one ``HostedViewHarness/render()`` pass before the test
/// reads the counts. Thus a count shows only the evaluations of that change,
/// and no window event or late update from outside the test adds to it.
///
/// The tests check the reuse with and without a transaction modifier that
/// disables animations above the hosted view, as the other hosted tests
/// apply it. A paragraph must not evaluate again in either case.
///
/// Diagnostic of task ^fzn2beh: in one full run, each earlier paragraph
/// evaluated again on each chunk, and the test passes alone. The cause is
/// not known yet. Each test records the window state of the process before
/// it mounts its view, and attaches that record to the test when a check
/// fails. The record does not change the result of the test.
@Suite(.serialized, .hostedSerially) @MainActor struct ParagraphReuseTests {
  /// The text that the hosted response view shows. A test appends each chunk
  /// to it, as the session model appends a chunk to the text of an entry.
  @Observable final class GrowingText {
    /// The whole text.
    var text: String

    /// Makes the text.
    ///
    /// - Parameter text: The first text.
    init(_ text: String) {
      self.text = text
    }
  }

  /// The response view of a growing text.
  struct GrowingResponse: View {
    /// The id of the response view.
    let id: String

    /// The text to show.
    let growing: GrowingText

    /// Whether a transaction modifier above the response view disables
    /// animations, as the other hosted tests do. The modifier was the fixed
    /// trigger of task ^fzn2beh: under it, each paragraph that came after the
    /// mount evaluated again on each chunk.
    let disablesAnimations: Bool

    var body: some View {
      if disablesAnimations {
        ResponseView(id: id, markdown: growing.text)
          .transaction { $0.disablesAnimations = true }
      } else {
        ResponseView(id: id, markdown: growing.text)
      }
    }
  }

  /// The size of the host window. It is tall enough for each paragraph.
  static let hostSize = CGSize(width: 480, height: 1_200)

  /// The number of paragraphs of the long text.
  static let paragraphCount = 8

  /// The name of the attachment that holds the window state record.
  static let windowStateAttachmentName = "window-state.txt"

  /// The chunks of the long text. Each paragraph comes in three chunks, and
  /// the first chunk of each paragraph after the first starts a new
  /// paragraph.
  static let chunks: [String] = (0..<paragraphCount).flatMap { index in
    [index == 0 ? "Paragraph" : "\n\nParagraph", " number \(index)", " ends here."]
  }

  /// The body evaluation count of each paragraph of `text`, keyed by counter
  /// key.
  ///
  /// - Parameters:
  ///   - text: The whole text of the response view.
  ///   - id: The id of the response view.
  /// - Returns: The count of each paragraph.
  static func counts(of text: String, id: String) -> [String: Int] {
    Dictionary(
      uniqueKeysWithValues: ParagraphSplitter.paragraphs(text).map { paragraph in
        let key = ParagraphView.counterKey(messageID: id, paragraphID: paragraph.id)
        return (key, BodyEvaluationCounter.count(key))
      })
  }

  /// Appends one chunk to the text, and makes one render pass.
  ///
  /// The change is on the main actor, so the pass applies it to the view
  /// graph at once, with no run loop turn. The caller then checks that the
  /// changed paragraphs evaluated.
  ///
  /// - Parameters:
  ///   - chunk: The chunk.
  ///   - growing: The text of the response view.
  ///   - harness: The harness that hosts the response view.
  static func append(_ chunk: String, to growing: GrowingText, harness: HostedViewHarness<some View>) {
    growing.text += chunk
    harness.render()
  }

  /// A text record of the window state of the process: each window of the
  /// application, the key window, the first responder of the key window,
  /// whether the application is active, and its appearance.
  ///
  /// A window that a test closed and that is still alive is in the list of
  /// the application windows, with `visible=false`.
  ///
  /// - Returns: One line for each value.
  static func windowStateRecord() -> String {
    let application = NSApplication.shared
    let windows = application.windows.map { window in
      "window \(type(of: window)) title=\"\(window.title)\" visible=\(window.isVisible) "
        + "key=\(window.isKeyWindow) releasedWhenClosed=\(window.isReleasedWhenClosed) "
        + "content=\(window.contentView.map { String(describing: type(of: $0)) } ?? "none")"
    }
    let keyWindow = application.keyWindow
    let summary = [
      "windows=\(windows.count)",
      "keyWindow=\(keyWindow.map { String(describing: type(of: $0)) } ?? "none")",
      "firstResponder=\(keyWindow?.firstResponder.map { String(describing: type(of: $0)) } ?? "none")",
      "isActive=\(application.isActive)",
      "appearance=\(application.effectiveAppearance.name.rawValue)",
    ]
    return (summary + windows).joined(separator: "\n")
  }

  /// Attaches the window state record to the current test.
  ///
  /// - Parameter record: The record from ``windowStateRecord()``.
  static func attachWindowState(_ record: String) {
    Attachment.record(record, named: windowStateAttachmentName)
  }

  @Test func aChunkThatStartsAParagraphEvaluatesOnlyTheChangedParagraphs() {
    let windowState = Self.windowStateRecord()
    let id = "paragraph-reuse-start"
    let growing = GrowingText("One.\n\nTwo")
    let harness = HostedViewHarness(
      GrowingResponse(id: id, growing: growing, disablesAnimations: true), size: Self.hostSize)
    defer { harness.close() }
    harness.render()
    let paragraphs = ParagraphSplitter.paragraphs(growing.text)
    let firstKey = ParagraphView.counterKey(messageID: id, paragraphID: paragraphs[0].id)
    #expect(BodyEvaluationCounter.count(firstKey) >= 1)
    BodyEvaluationCounter.reset(prefix: ParagraphView.counterKeyPrefix + id)

    Self.append(".\n\nThree", to: growing, harness: harness)

    let thirdKey = ParagraphView.counterKey(
      messageID: id, paragraphID: ParagraphSplitter.paragraphs(growing.text)[2].id)
    let firstCount = BodyEvaluationCounter.count(firstKey)
    let firstIsReused = firstCount == 0
    #expect(firstIsReused, "The first paragraph evaluated again: \(firstCount) times.")
    if !firstIsReused {
      Self.attachWindowState(windowState)
    }
    #expect(BodyEvaluationCounter.count(thirdKey) >= 1, "The new paragraph did not evaluate.")
    BodyEvaluationCounter.reset(prefix: ParagraphView.counterKeyPrefix + id)
  }

  /// The check runs with and without a transaction modifier above the
  /// response view. Each case has its own response id, so the counter keys
  /// of the two cases are apart.
  ///
  /// - Parameter disablesAnimations: Whether the transaction modifier is
  ///   above the response view.
  @Test(arguments: [true, false])
  func aLongTextNeverEvaluatesAnEarlierParagraphAgain(disablesAnimations: Bool) {
    let windowState = Self.windowStateRecord()
    let id = "paragraph-reuse-long-\(disablesAnimations ? "transaction" : "plain")"
    let growing = GrowingText("")
    let harness = HostedViewHarness(
      GrowingResponse(id: id, growing: growing, disablesAnimations: disablesAnimations), size: Self.hostSize)
    defer { harness.close() }
    harness.render()

    // A chunk can change the text of the last paragraph, and so its id. Each
    // paragraph before the last one keeps its text, its id and its count.
    var previous: [String: Int] = [:]
    var previousLastKey: String?
    var anEarlierParagraphEvaluated = false
    for chunk in Self.chunks {
      Self.append(chunk, to: growing, harness: harness)
      let current = Self.counts(of: growing.text, id: id)
      for (key, count) in previous where key != previousLastKey {
        let isReused = current[key] == count
        #expect(isReused, "The earlier paragraph \(key) evaluated again: \(String(describing: current[key])) after \(count).")
        anEarlierParagraphEvaluated = anEarlierParagraphEvaluated || !isReused
      }
      for (key, count) in current where previous[key] == nil {
        #expect(count >= 1, "The new paragraph \(key) did not evaluate.")
      }
      previous = current
      previousLastKey = ParagraphSplitter.paragraphs(growing.text).last.map {
        ParagraphView.counterKey(messageID: id, paragraphID: $0.id)
      }
    }
    if anEarlierParagraphEvaluated {
      Self.attachWindowState(windowState)
    }

    #expect(ParagraphSplitter.paragraphs(growing.text).count == Self.paragraphCount)
    BodyEvaluationCounter.reset(prefix: ParagraphView.counterKeyPrefix + id)
  }
}
