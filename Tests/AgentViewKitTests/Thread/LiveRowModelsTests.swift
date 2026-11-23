import AgentViewKitTestSupport
import AppKit
import EditorText
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// The rows of a transcript of agent answers, as ``ConversationView`` shows
/// them, in an `NSHostingView` with no window.
///
/// A window-less host cannot scroll a SwiftUI `ScrollView`: the document view
/// of the scroll view has no size, and a new scroll position or clip view
/// origin does not move the rows (measured on macOS 27, task ^t9416x5). So
/// the host shows the rows in a `VStack` (``TranscriptRowsStack``). A `VStack`
/// keeps each row, which is the worst case of the lazy stack of
/// ``ConversationView``. The host moves the rows in view with
/// ``LiveRowRange/noteVisible(positions:)``, the call
/// that ``ConversationView`` makes when the list reports the rows in view.
///
/// The host counts the editors that are alive. Each EditorKit editor of a
/// row has one `EditorTextScaffold`, the delegate of its text view, and one
/// model. The editor holds its scaffold and its model, and the two go away
/// together when the editor goes away: a probe that removed one
/// `RenderedMarkdownView` from a window-less host saw its model and its
/// scaffold freed at once. The host keeps a weak reference to each scaffold
/// that it finds. It does not count the text views: AppKit does not free an
/// `NSTextView` at its last release in a window-less test process, also a
/// text view that no SwiftUI view ever held (task ^t9416x5).
@MainActor final class TranscriptRowsHost {
  /// The width of the rows, in points.
  static let width: CGFloat = 600

  /// The rows that keep their models.
  let rows = LiveRowRange()

  /// The session whose transcript the host shows.
  let session: SessionModel

  /// The host of the rows.
  private let hosting: NSHostingView<AnyView>

  /// A weak reference to the scaffold of each editor that the host found.
  private var scaffolds: [ObjectIdentifier: WeakScaffold] = [:]

  /// Shows the rows of one agent answer for each text, and lays them out.
  ///
  /// - Parameter answers: The Markdown text of each answer.
  init(answers: [String]) {
    let session = SessionModel.preview(transcript: answers.map { .agent($0) })
    self.session = session
    hosting = NSHostingView(
      rootView: AnyView(TranscriptRowsStack.view(of: session, rows: rows, width: Self.width)))
    layOut()
  }

  /// The number of editors that are alive.
  var liveEditorCount: Int {
    scaffolds.values.count { $0.scaffold != nil }
  }

  /// The number of text views in the view tree of the host.
  var mountedTextViewCount: Int {
    Self.textViews(in: hosting).count
  }

  /// The height of the rows, in points.
  var height: CGFloat {
    hosting.fittingSize.height
  }

  /// Reports the rows in view, lays out the rows again, and records each
  /// editor.
  ///
  /// - Parameter positions: The positions of the rows in view.
  func show(_ positions: Range<Int>) {
    rows.noteVisible(positions: Array(positions))
    layOut()
  }

  /// Lays out the rows, and records the editor of each text view in the
  /// view tree.
  private func layOut() {
    autoreleasepool {
      hosting.frame = NSRect(origin: .zero, size: hosting.fittingSize)
      hosting.layoutSubtreeIfNeeded()
      for scaffold in Self.textViews(in: hosting).compactMap({ $0.delegate as? EditorTextScaffold })
      {
        scaffolds[ObjectIdentifier(scaffold)] = WeakScaffold(scaffold)
      }
    }
  }

  /// The text views in the view tree under `view`.
  ///
  /// - Parameter view: The root of the tree.
  /// - Returns: Each text view of the tree.
  private static func textViews(in view: NSView) -> [NSTextView] {
    let own = (view as? NSTextView).map { [$0] } ?? []
    return own + view.subviews.flatMap { textViews(in: $0) }
  }
}

/// A weak reference to the scaffold of an editor.
private final class WeakScaffold {
  /// The scaffold, or `nil` after its editor went away.
  weak var scaffold: EditorTextScaffold?

  /// Makes a weak reference to `scaffold`.
  ///
  /// - Parameter scaffold: The scaffold.
  init(_ scaffold: EditorTextScaffold) {
    self.scaffold = scaffold
  }
}

/// Tests that a long transcript keeps a bounded number of live EditorKit
/// models (task ^t9416x5).
///
/// One rendered answer keeps about 659 KiB in its model and its editor
/// (EditorKit benchmark). A row far from the rows in view must not keep them.
@MainActor @Suite struct LiveRowModelsTests {
  /// The number of answers in the transcript. It is larger than the rows in
  /// view and the margins on both sides.
  static let answerCount = 80

  /// The number of rows in view at each step of the scroll.
  static let visibleCount = 4

  /// The texts of a transcript of ``answerCount`` answers.
  static let answers = (0..<answerCount).map { "Answer \($0) with **bold** text." }

  /// The largest number of rows that keep an editor: the rows in view and
  /// the margin on each side of them.
  static let liveBound = visibleCount + 2 * LiveRowRange.margin

  /// Scrolls the host from the top to the bottom of the transcript, one view
  /// at a time.
  ///
  /// - Parameter host: The host.
  static func scrollThrough(_ host: TranscriptRowsHost) {
    for first in stride(from: 0, to: answerCount - visibleCount + 1, by: visibleCount) {
      host.show(first..<(first + visibleCount))
    }
  }

  /// A production change that fails this test: a row keeps its model and
  /// its editor when it is far from the rows in view, so each row that the
  /// lazy stack keeps holds its model.
  @Test func aScrollThroughALongTranscriptKeepsABoundedNumberOfEditors() {
    let host = TranscriptRowsHost(answers: Self.answers)

    Self.scrollThrough(host)

    #expect(host.liveEditorCount <= Self.liveBound)
  }

  /// A production change that fails this test: a row in view, or in the
  /// margin of the rows in view, shows no editor, or a row far from them
  /// keeps its editor in the view tree.
  @Test func eachLiveRowAndNoOtherRowShowsAnEditor() {
    let host = TranscriptRowsHost(answers: Self.answers)

    Self.scrollThrough(host)

    #expect(host.mountedTextViewCount == (0..<Self.answerCount).count { host.rows.isLive($0) })
  }

  /// A production change that fails this test: a row that drops its editor
  /// changes its height, so the rows below it move.
  @Test func aRowThatDropsItsEditorKeepsItsHeight() {
    let host = TranscriptRowsHost(answers: Self.answers)
    let height = host.height

    host.show(0..<Self.visibleCount)

    #expect(host.height == height)
  }
}

/// Tests that a response whose row was far from the rows in view shows its
/// whole text when its row comes back (task ^t9416x5).
@MainActor @Suite struct LiveRowStreamingTests {
  /// The position of the row of the response.
  static let position = 0

  /// A position far from the row of the response.
  static let farPosition = 1_000

  /// The response in the row at ``position``.
  ///
  /// - Parameters:
  ///   - text: The Markdown text of the response.
  ///   - rows: The rows that keep their models.
  ///   - cache: The cache of the models, or `nil` when the response keeps
  ///     its own model.
  /// - Returns: The view.
  static func response(_ text: String, rows: LiveRowRange, cache: CodeBlockModelCache? = nil)
    -> AnyView
  {
    AnyView(
      ResponseView(id: "answer", markdown: text)
        .modifier(TranscriptRowLiveness(position: position))
        .environment(\.liveRowRange, rows)
        .environment(\.codeBlockModelCache, cache)
        .frame(width: TranscriptRowsHost.width))
  }

  /// Shows a response with the text "One.", moves the live rows away from
  /// it, gives it the text "One. Two.", and moves the live rows back.
  ///
  /// - Parameter cache: The cache of the models, or `nil`.
  /// - Returns: The host of the response.
  static func growWhileFar(cache: CodeBlockModelCache?) -> NSHostingView<AnyView> {
    let rows = LiveRowRange()
    let hosting = NSHostingView(rootView: Self.response("One.", rows: rows, cache: cache))
    Self.layOut(hosting)
    rows.noteVisible(positions: [Self.farPosition])
    hosting.rootView = Self.response("One. Two.", rows: rows, cache: cache)
    Self.layOut(hosting)

    rows.noteVisible(positions: [Self.position])
    Self.layOut(hosting)
    return hosting
  }

  /// Lays out `hosting` at its fitting size.
  ///
  /// - Parameter hosting: The host.
  static func layOut(_ hosting: NSHostingView<AnyView>) {
    hosting.frame = NSRect(origin: .zero, size: hosting.fittingSize)
    hosting.layoutSubtreeIfNeeded()
  }

  /// A production change that fails this test: a response keeps the text of
  /// the model that it dropped, so a text that streamed in while its row was
  /// far does not show.
  @Test func aTextThatGrowsWhileItsRowIsFarShowsWholeWhenTheRowComesBack() throws {
    let hosting = Self.growWhileFar(cache: nil)

    let textView = try #require(hosting.firstTextView)
    #expect(textView.string == "One. Two.")
  }

  /// A production change that fails this test: a response whose row comes
  /// back shows the model of the thread cache with the old text of the
  /// model, so a text that streamed in while the row was far does not show
  /// (task ^3qvtsgh).
  @Test func aTextThatGrowsWhileItsRowIsFarShowsWholeFromTheCacheWhenTheRowComesBack() throws {
    let hosting = Self.growWhileFar(cache: CodeBlockModelCache())

    let textView = try #require(hosting.firstTextView)
    #expect(textView.string == "One. Two.")
  }

  /// A production change that fails this test: a response that is not in a
  /// thread row, such as a response in a side card of a thread, drops its
  /// editor when the live rows of the thread move.
  @Test func aResponseOutsideAThreadRowKeepsItsEditorWhenTheLiveRowsMove() {
    let rows = LiveRowRange()
    let hosting = NSHostingView(
      rootView: AnyView(
        ResponseView(id: "answer", markdown: "One.")
          .environment(\.liveRowRange, rows)
          .frame(width: TranscriptRowsHost.width)))
    Self.layOut(hosting)

    rows.noteVisible(positions: [Self.farPosition])
    Self.layOut(hosting)

    #expect(hosting.firstTextView != nil)
  }
}

extension NSView {
  /// The first text view in the view tree under this view, depth first.
  var firstTextView: NSTextView? {
    (self as? NSTextView) ?? subviews.lazy.compactMap(\.firstTextView).first
  }
}
