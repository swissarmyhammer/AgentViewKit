#if DEBUG
  /// The judgement of the reviewer of each screen of the review gallery
  /// (^8q34yt8), that the contact sheet shows under the row of the screen.
  ///
  /// A note names the date of the review and the id of each card that a
  /// finding made. When a screen changes, review its images again and write
  /// a new note. The review judges only what the kit draws: path A of
  /// `ViewSnapshot` draws no Liquid Glass and no scroll edge effect, and the
  /// limits of the dark images are on ^zbcys18.
  enum ReviewGalleryNotes {
    /// The note of a screen that no reviewer judged.
    static let notJudged = "Not judged yet."

    /// The note of each judged screen.
    static let notes: [ReviewGalleryScreen: String] = [
      .thread: """
        2026-10-27. No fill behind the messages, the code block, the terminal output, the tool calls, the plan or \
        the header; each has thin separator edges. The location chip "SearchIndex.swift:2" has the quaternary \
        capsule that AVK-8r allows (text 12.6:1 light, 9.4:1 dark). The selected file row of the diff uses the \
        gray selection surface. Findings: the diff text wraps while its gutter and line colors do not, so the \
        lines do not match and the last lines are cut off (^q89x329); "Exit code 0" is green text at 2.2:1 in \
        light (^sbx2q4h); the diff counts "+1 −1" are 1.9:1 in light (^a2dy2gt). Not visible in this render \
        path: the mic, Send and mode picker of the accessory row, and the glass of the composer (^zbcys18).
        """,
      .requestDeck: """
        2026-10-27. The request cards have no fill. The cards behind the front card show as thin top edges, so \
        the deck reads as a stack ("1 of 2"). The text of the front card is 8.5:1 in light. In dark, the \
        bordered buttons on the deck glass draw white because this path draws no glass, as in the recorded \
        request-deck-bar-dark.png (^zbcys18). Glass on glass, and the text of the card over the scrolled list, \
        cannot be judged without glass. Finding: the pending status symbol of the tool call is 1.9:1 in light \
        and 2.3:1 in dark (^fppqe0q).
        """,
      .banners: """
        2026-10-27. The connection banner, the three notices, the error entry and the state banner have no \
        fill, only thin edges. The notice symbols use the severity roles (the info role is the system blue, \
        not the accent). "Show Error" draws a black label in dark, a limit of glass buttons in this path \
        (^zbcys18). Finding: the "Sent" text is green at 2.2:1 in light (^sbx2q4h).
        """,
      .signIn: """
        2026-10-27. The sign-in card has no fill; Sign In and Sign Out keep the glass styles in the bar. The \
        attachment chip "Release.zip" has the quaternary fill that AVK-8r allows: name 12.6:1 light and 9.4:1 \
        dark, size 3.8:1 light, the same as secondary text, so no card. The glass button labels draw black in \
        dark (^zbcys18). Finding: the "Sent" text (^sbx2q4h).
        """,
      .scrolled: """
        2026-10-27. The rows show behind the top bar and the bottom bar, so no opaque fill is behind either \
        bar (this path draws no scroll edge effect). The "Scroll to Bottom" pill floats over the rows with no \
        fill of its own. Finding: the "Sent" text (^sbx2q4h).
        """,
      .inspector: """
        2026-10-27. The thread column has no fill, and the inspector form hides its own background, so the \
        column shows the system inspector background. In dark the grouped-form rows draw white with black \
        text: a plain SwiftUI inspector with a grouped form does the same in this path, and the recorded \
        attachment-inspector-dark.png shows dark rows (^zbcys18). The QuickLook preview is hidden on purpose.
        """,
      .gallery: """
        2026-10-27. The sidebar shows the system sidebar background, with no kit fill. The open "Permission \
        request" session shows its pending-request count badge (an AVK-8r chip); its color, and the row \
        titles in dark, cannot be judged, because sidebar list rows do not take the dark look in this path \
        (^zbcys18). The Look popover is not in the image: a popover is its own window. The detail is the \
        resumed permission session, with the partial-history banner (no fill) and the permission card.
        """,
    ]
  }
#endif
