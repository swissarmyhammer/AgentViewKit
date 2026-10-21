@testable import AgentViewKit
import AgentViewKitTestSupport
import FoundationModelsACPClient
import SwiftUI
import Testing

/// Checks that each glass view of the kit follows Reduce Transparency and
/// Increase Contrast (D110 (f), TestudoApp `features/style.md` rule 9).
///
/// The test uses the method of ^dbbyg9w (``GlassRenderProbeTests``): it
/// renders a glass view over the backdrop two times with ``RenderedPixels``,
/// one time with the setting off and one time with the setting on, in light
/// mode, with the other setting off. Then it expects different pixels in each
/// glass of the view.
///
/// The test finds each glass of the view on one row of the render: a glass is
/// a span of pixels that do not show the backdrop. Thus the test also expects
/// the number of glasses, for example the three buttons of the accessory row
/// while the agent runs. The test compares only two points of each glass:
/// ``rimClearance`` in from its leading and its trailing edge. The rim of a
/// rounded glass changes after its first renders in the process, at a render
/// that is not the same in each run (``RenderedPixels/isClose(to:at:tolerance:)``),
/// so the points are not on the rim. The points are also not on the label of
/// a button, which can keep its pixels when only the glass changes.
///
/// The test does not check the Tinted look and the Clear look. They are
/// system settings, and a test cannot set them (D113 answers 3 and 6). AVK-8u
/// (^8q34yt8) checks them by hand, with screenshots of the demo app.
@Suite @MainActor struct GlassAccessibilityTests {
  /// The distance from the leading or the trailing edge of a glass to the
  /// point that the test compares, in points. The rim changes only within 2
  /// points of the edge, so the point is not on the rim.
  static let rimClearance: CGFloat = 4

  @Test(arguments: GlassView.allCases, GlassProbeSetting.allCases)
  func eachGlassOfTheViewFollowsTheSetting(view: GlassView, setting: GlassProbeSetting) throws {
    let spans = try Self.glassSpans(of: view)
    #expect(spans.count == view.glassCount)
    for span in spans {
      try GlassRenderProbeTests.expectDifferentPixels(
        of: view.content, with: setting, at: Self.points(in: span, row: view.row), size: view.size)
    }
  }

  /// The spans of the glasses of `view` on its row, from the leading edge to
  /// the trailing edge, in the render with each setting off.
  ///
  /// - Parameter view: The glass view.
  /// - Returns: The spans, in points from the leading edge of the render.
  /// - Throws: An error when the renderer gives no pixels.
  static func glassSpans(of view: GlassView) throws -> [ClosedRange<CGFloat>] {
    let pixels = try GlassRenderProbeTests.pixels(of: view.content, size: view.size)
    let step = 1 / RenderedPixels.renderScale
    let glassColumns = stride(from: step / 2, to: view.size.width, by: step).filter { x in
      !pixels.contains(GlassRenderProbeTests.backdrop, at: CGPoint(x: x, y: view.row))
    }
    return spans(of: glassColumns, step: step)
  }

  /// Joins the adjacent values of `columns` into spans.
  ///
  /// - Parameters:
  ///   - columns: The centers of the glass pixels of a row, in increasing
  ///     order.
  ///   - step: The distance between the centers of two adjacent pixels.
  /// - Returns: One span for each group of adjacent columns.
  static func spans(of columns: [CGFloat], step: CGFloat) -> [ClosedRange<CGFloat>] {
    columns.reduce(into: []) { spans, column in
      if let last = spans.last, column - last.upperBound <= step {
        spans[spans.count - 1] = last.lowerBound...column
      } else {
        spans.append(column...column)
      }
    }
  }

  /// The two points that the test compares in the glass of `span`.
  ///
  /// - Parameters:
  ///   - span: The span of the glass on its row.
  ///   - row: The row of the span.
  /// - Returns: The point ``rimClearance`` in from the leading edge, and the
  ///   point ``rimClearance`` in from the trailing edge.
  static func points(in span: ClosedRange<CGFloat>, row: CGFloat) -> [CGPoint] {
    [CGPoint(x: span.lowerBound + rimClearance, y: row), CGPoint(x: span.upperBound - rimClearance, y: row)]
  }

  @Test func adjacentColumnsMakeOneSpanAndAGapStartsANewSpan() {
    let step: CGFloat = 0.5
    let spans = Self.spans(of: [1, 1.5, 2, 4, 4.5], step: step)
    #expect(spans == [1...2, 4...4.5])
  }
}

/// A glass view of the kit over the backdrop of ``GlassRenderProbeTests``.
///
/// The type is `nonisolated` because the arguments of a test use its cases.
nonisolated enum GlassView: CaseIterable, Sendable {
  /// The field of the full composer, on the floating glass of the kit
  /// (``PromptFieldSurface``). `ImageRenderer` does not draw the editor of
  /// the composer, because it can take the VoiceOver focus
  /// (``ContentEdgeHostedProbe``), but it draws the field glass around it.
  case composerField

  /// The menu of the editor above the field, on its own floating glass
  /// (``PromptEditorMenuLayer``).
  case editorMenu

  /// The accessory row while the agent does not run: the dictation button
  /// with the `.glass` style, and Send with the `.glassProminent` style.
  /// `ImageRenderer` does not draw the permission mode picker, which is an
  /// AppKit control.
  case accessoryWhileIdle

  /// The accessory row while the agent runs: the dictation button and Send
  /// with the `.glass` style, and Stop with the `.glassProminent` style.
  case accessoryWhileRunning

  /// One suggestion chip (``SuggestionChip``). `ImageRenderer` draws nothing
  /// in the horizontal scroll view of ``SuggestionsView``, so the test
  /// renders the chip out of it.
  case suggestionChip

  /// The scroll-to-bottom pill.
  case scrollPill

  /// A ``RequestDeck`` in a bar of floating controls, on the floating glass
  /// of the kit. `ImageRenderer` does not draw the cards, because they can
  /// take the VoiceOver focus, but it draws the glass of the deck as a band
  /// across the full width.
  case requestDeckInBar

  /// A primary and a secondary action of a request card in content, with the
  /// `.glassProminent` and the `.glass` style (``RequestDeckPlace/style(of:)``).
  case requestActionsInContent

  /// The width of the render of a row of glass buttons and of the composer,
  /// in points.
  static let renderWidth: CGFloat = 320

  /// The height of the render of a row of glass buttons, in points.
  static let buttonRowHeight: CGFloat = 80

  /// The height of the render of the composer, in points.
  static let composerHeight: CGFloat = 200

  /// The size of the render of a row of glass buttons, in points.
  static let buttonRowSize = CGSize(width: renderWidth, height: buttonRowHeight)

  /// The size of the render of the composer, in points.
  static let composerSize = CGSize(width: renderWidth, height: composerHeight)

  /// The number of glasses of the accessory row while the agent runs: the
  /// dictation button, Send and Stop.
  static let accessoryGlassCountWhileRunning = 3

  /// The number of glasses of the accessory row while the agent does not
  /// run: the dictation button and Send.
  static let accessoryGlassCountWhileIdle = 2

  /// The number of glasses of ``requestActions``: the primary and the
  /// secondary action.
  static let requestActionGlassCount = 2

  /// The number of new items that the scroll-to-bottom pill shows.
  static let newItemCount = 3

  /// The text of the suggestion chip.
  static let suggestion = "Explain the build error"

  /// The size of the render, in points.
  @MainActor var size: CGSize {
    switch self {
    case .composerField: Self.composerSize
    case .editorMenu: EditorMenuProbe.size
    case .requestDeckInBar: RequestDeckSurfaceTests.size
    case .accessoryWhileIdle, .accessoryWhileRunning, .suggestionChip, .scrollPill, .requestActionsInContent:
      Self.buttonRowSize
    }
  }

  /// The row of the render that goes through the middle of each glass, in
  /// points from the top.
  @MainActor var row: CGFloat {
    switch self {
    case .editorMenu: EditorMenuProbe.menuRow
    case .composerField, .requestDeckInBar, .accessoryWhileIdle, .accessoryWhileRunning, .suggestionChip,
      .scrollPill, .requestActionsInContent:
      CGRect(origin: .zero, size: size).midY
    }
  }

  /// The number of glasses on ``row``.
  var glassCount: Int {
    switch self {
    case .accessoryWhileRunning: Self.accessoryGlassCountWhileRunning
    case .accessoryWhileIdle: Self.accessoryGlassCountWhileIdle
    case .requestActionsInContent: Self.requestActionGlassCount
    case .composerField, .editorMenu, .suggestionChip, .scrollPill, .requestDeckInBar: 1
    }
  }

  /// The view over the backdrop.
  @MainActor var content: AnyView {
    switch self {
    case .composerField:
      AnyView(Self.overBackdrop(PromptInputView(text: .constant(AttributedString())) {}))
    case .editorMenu: AnyView(EditorMenuProbe())
    case .accessoryWhileIdle: AnyView(Self.accessory(for: SnapshotFixtures.idleSession))
    case .accessoryWhileRunning: AnyView(Self.accessory(for: SnapshotFixtures.runningSession))
    case .suggestionChip: AnyView(Self.overBackdrop(Self.firstSuggestionChip))
    case .scrollPill: AnyView(Self.overBackdrop(ScrollToBottomPill(newItemCount: Self.newItemCount) {}))
    case .requestDeckInBar: AnyView(RequestDeckSurfaceTests.deck(inBar: true))
    case .requestActionsInContent: AnyView(Self.overBackdrop(Self.requestActions))
    }
  }

  /// `view` over the backdrop, with no inset (``OverBackdrop``).
  ///
  /// - Parameter view: The glass view.
  /// - Returns: The view over the backdrop.
  @MainActor static func overBackdrop(_ view: some View) -> some View {
    OverBackdrop(inset: 0) { view }
  }

  /// The default accessory row of the composer of `session`, with a
  /// dictation button and an enabled Send, over the backdrop. The row has
  /// the medium spacing of the theme on each side, so that Send is not at
  /// the edge of the render.
  ///
  /// - Parameter session: The session of the composer.
  /// - Returns: The view.
  @MainActor static func accessory(for session: SessionModel) -> some View {
    overBackdrop(
      DefaultPromptAccessory()
        .padding(.horizontal, AgentTheme.default.spacing.m)
        .environment(\.sessionModel, session)
        .environment(\.promptText, .constant(AttributedString()))
        .environment(\.speechTranscriber, FakeSpeechTranscriber())
        .environment(\.promptSubmitAction, PromptSubmitAction(isEnabled: true) {}))
  }

  /// The first chip of a list of suggestions, with ``suggestion``.
  @MainActor static var firstSuggestionChip: some View {
    SuggestionChip(suggestion: suggestion, index: 0, text: .constant(AttributedString()))
  }

  /// A primary and a secondary action of a request card, out of a bar.
  @MainActor static var requestActions: some View {
    HStack(spacing: AgentTheme.default.spacing.s) {
      Button("Allow once") {}.requestActionStyle(.primary)
      Button("Deny") {}.requestActionStyle(.secondary)
    }
  }
}

/// The menu layer of the composer (``PromptEditorMenuLayer``) above a clear
/// stand-in of the field, at the bottom of the render, over the backdrop.
///
/// The probe uses the shared backdrop (``OverBackdrop``) with no inset, and
/// puts the stand-in at the bottom edge of the render.
///
/// The stand-in gives its bounds as the anchor of the menu, as the editor of
/// the composer does. The menu has clear content, so that its glass shows
/// the backdrop.
struct EditorMenuProbe: View {
  /// The width of the render, in points.
  static let width: CGFloat = 240

  /// The height of the render, in points.
  static let height: CGFloat = 160

  /// The size of the render, in points.
  static let size = CGSize(width: width, height: height)

  /// The height of the stand-in of the field, in points.
  static let fieldHeight: CGFloat = 60

  /// The width of the content of the menu, in points.
  static let menuWidth: CGFloat = 160

  /// The height of the content of the menu, in points.
  static let menuHeight: CGFloat = 40

  /// The size of the content of the menu, in points.
  static let menuSize = CGSize(width: menuWidth, height: menuHeight)

  /// The middle row of the menu, in points from the top of the render. The
  /// bottom edge of the menu is the small spacing of the theme above the
  /// top edge of the field.
  static var menuRow: CGFloat {
    let menuBottom = size.height - fieldHeight - AgentTheme.default.spacing.s
    return menuBottom - CGRect(origin: .zero, size: menuSize).midY
  }

  var body: some View {
    OverBackdrop(inset: 0) {
      FloatingGlassContainer(spacing: AgentTheme.default.spacing.s) {
        Color.clear
          .frame(height: Self.fieldHeight)
          .anchorPreference(key: PromptEditorMenuKey.self, value: .bounds) { anchor in
            PromptEditorMenu(anchor: anchor, content: AnyView(Self.menuContent))
          }
          .overlayPreferenceValue(PromptEditorMenuKey.self, alignment: .topLeading) { menu in
            if let menu {
              PromptEditorMenuLayer(menu: menu)
            }
          }
      }
      .frame(maxHeight: .infinity, alignment: .bottom)
    }
  }

  /// The clear content of the menu.
  static var menuContent: some View {
    Color.clear.frame(width: menuSize.width, height: menuSize.height)
  }
}
