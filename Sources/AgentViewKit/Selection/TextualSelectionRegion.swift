import AppKit
import EditorSwiftUI
import SwiftUI
import Textual

// A Textual text area in the one selection of a thread
// (Docs/decisions/text-selection.md).
//
// Textual 0.5.0 gives each `StructuredText` its own selection model and its
// own coordinator. The types are internal, so the kit cannot give the text
// views one shared model. The kit uses two public facts instead:
//
// - A click in a selectable `StructuredText` makes the Textual interaction
//   view (`NSTextInteractionView`) the first responder of the window. The
//   view is an overlay with the frame of the text.
// - A `StructuredText` with a new identity has no selection.
//
// So a probe view in the background of the text observes the first
// responder of its window. When the interaction view in the frame of the
// probe becomes the first responder, the area claims the selection of the
// thread. When a different area claims the selection, the area gives the
// text a new identity, and the old selection goes away.

extension View {
  /// Makes the Textual text of the view selectable, as one area of the one
  /// selection of the thread.
  ///
  /// Apply the modifier directly to one `StructuredText`. With no selection
  /// region in the environment, the text is selectable and keeps its own
  /// selection.
  func selectableTextualRegion() -> some View {
    modifier(TextualSelectionRegion())
  }
}

/// The owner of the selection of one Textual area.
///
/// The owner stays for the life of the area, so a claim from the same area
/// is a claim from the same owner.
@MainActor @Observable
final class TextualSelectionOwner {
  /// The identity of the text. A change makes the text again with no
  /// selection.
  private(set) var generation = 0

  /// Removes the selection of the area: the text gets a new identity.
  func clear() {
    generation += 1
  }
}

/// Turns on the Textual selection of a text, and registers the text as one
/// area of the selection region in the environment.
private struct TextualSelectionRegion: ViewModifier {
  @Environment(\.textSelectionRegion) private var region
  @State private var owner = TextualSelectionOwner()

  func body(content: Content) -> some View {
    content
      .id(owner.generation)
      .textual.textSelection(.enabled)
      .background {
        if let region {
          TextualSelectionProbe(region: region, owner: owner)
            .accessibilityHidden(true)
        }
      }
  }
}

/// The background view that sees a click in the Textual text above it.
private struct TextualSelectionProbe: NSViewRepresentable {
  /// The selection region of the thread.
  let region: any TextSelectionRegion

  /// The owner of the area.
  let owner: TextualSelectionOwner

  func makeNSView(context: Context) -> TextualSelectionProbeView {
    TextualSelectionProbeView(region: region, owner: owner)
  }

  func updateNSView(_ view: TextualSelectionProbeView, context: Context) {
    view.update(region: region, owner: owner)
  }

  static func dismantleNSView(_ view: TextualSelectionProbeView, coordinator: ()) {
    view.leaveRegion()
  }
}

/// The view of a ``TextualSelectionProbe``.
///
/// The view takes no event and draws nothing. It observes the first
/// responder of its window while it is in a window.
final class TextualSelectionProbeView: NSView {
  /// The type name of the Textual interaction view (Textual 0.5.0,
  /// `NSTextInteractionView.swift`). The pin of Textual is exact, so the
  /// name changes only with a new pin.
  nonisolated static let interactionTypeName = "NSTextInteractionView"

  /// The tolerance of the frame test, in points.
  nonisolated static let frameTolerance: CGFloat = 1

  private var region: any TextSelectionRegion
  private var owner: TextualSelectionOwner
  private var observation: NSKeyValueObservation?

  init(region: any TextSelectionRegion, owner: TextualSelectionOwner) {
    self.region = region
    self.owner = owner
    super.init(frame: .zero)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is not available")
  }

  /// Uses a new region or owner. A change of region releases the area from
  /// the old region.
  func update(region: any TextSelectionRegion, owner: TextualSelectionOwner) {
    if self.region !== region || self.owner !== owner {
      self.region.release(self.owner)
    }
    self.region = region
    self.owner = owner
  }

  /// Releases the area from its region and stops the observation.
  func leaveRegion() {
    observation = nil
    region.release(owner)
  }

  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    observation = nil
    guard let window else {
      region.release(owner)
      return
    }
    observation = window.observe(\.firstResponder, options: [.new]) { [weak self] window, _ in
      MainActor.assumeIsolated {
        self?.firstResponderDidChange(window.firstResponder)
      }
    }
  }

  /// Claims the selection when `responder` is the Textual interaction view
  /// of this area.
  private func firstResponderDidChange(_ responder: NSResponder?) {
    guard let responder = responder as? NSView, let window, responder.window === window else { return }
    let claims = Self.claims(
      responderTypeName: String(describing: type(of: responder)),
      responderFrame: responder.convert(responder.bounds, to: nil),
      probeFrame: convert(bounds, to: nil))
    if claims {
      let owner = owner
      region.claim(owner) { [weak owner] in owner?.clear() }
    }
  }

  /// Tells if a new first responder is the Textual interaction view of the
  /// area of a probe.
  ///
  /// The interaction view is an overlay of the text, and the probe is the
  /// background of the same text. So the interaction view of the area is in
  /// the frame of the probe. A code block in the text is an EditorKit view,
  /// not a Textual interaction view, so it claims for itself.
  ///
  /// - Parameters:
  ///   - responderTypeName: The type name of the new first responder.
  ///   - responderFrame: The frame of the new first responder, in window
  ///     coordinates.
  ///   - probeFrame: The frame of the probe, in window coordinates.
  /// - Returns: `true` when the area claims the selection.
  nonisolated static func claims(responderTypeName: String, responderFrame: CGRect, probeFrame: CGRect)
    -> Bool
  {
    guard responderTypeName == interactionTypeName, !probeFrame.isEmpty else { return false }
    return probeFrame.insetBy(dx: -frameTolerance, dy: -frameTolerance).contains(responderFrame)
  }
}

// MARK: - Selectable plain text

/// A plain text that the user can select, as one area of the one selection
/// of the thread.
///
/// Use it in place of a SwiftUI `Text` with `.textSelection(.enabled)` in
/// the transcript: the kit cannot clear a SwiftUI selection, so a SwiftUI
/// selection does not take part in the one selection of the thread. The text
/// wraps; Textual does not truncate.
///
/// For VoiceOver the view is one static text element with the text as its
/// label, as a SwiftUI `Text` is.
struct SelectableText: View {
  /// The text, with its attributes.
  let text: AttributedString

  /// The VoiceOver label, or `nil` for the text.
  let label: String?

  /// Makes a selectable text of a plain string.
  ///
  /// - Parameters:
  ///   - text: The text.
  ///   - label: The VoiceOver label, or `nil` for the text.
  init(_ text: String, label: String? = nil) {
    self.text = AttributedString(text)
    self.label = label
  }

  /// Makes a selectable text of an attributed string, such as a URL with
  /// its host in bold.
  ///
  /// - Parameters:
  ///   - text: The text, with its attributes.
  ///   - label: The VoiceOver label, or `nil` for the text.
  init(_ text: AttributedString, label: String? = nil) {
    self.text = text
    self.label = label
  }

  var body: some View {
    let plain = String(text.characters)
    // The hidden SwiftUI text gives the view the size of a SwiftUI `Text`:
    // its ideal width is the width of one line. `StructuredText` has no
    // size until it parses its text after it appears, and again after a
    // clear of its selection makes it again.
    ZStack(alignment: .topLeading) {
      Text(text)
        .hidden()
      StructuredText(plain, parser: FixedTextParser(text: text))
        .selectableTextualRegion()
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(verbatim: label ?? plain))
    .accessibilityAddTraits(.isStaticText)
  }
}

/// A Textual parser that gives an attributed string that the view already
/// has.
///
/// `StructuredText` parses its markup again when the markup changes. The
/// markup of a ``SelectableText`` is the characters of its text, so a new
/// text with new characters parses again.
private struct FixedTextParser: MarkupParser {
  /// The text that the parser gives.
  let text: AttributedString

  /// Gives ``text``.
  ///
  /// - Parameter input: The characters of ``text``.
  /// - Returns: ``text``.
  func attributedString(for input: String) throws -> AttributedString {
    text
  }
}
