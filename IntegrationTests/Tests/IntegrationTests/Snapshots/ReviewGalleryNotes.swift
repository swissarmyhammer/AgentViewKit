#if DEBUG
  import EditorTestSupport

  /// The judgement of the reviewer of each key screen of the review gallery
  /// (^8q34yt8), that the page shows under the row of the screen as an
  /// EditorKit `ReviewNote`: the day of the review and the text.
  ///
  /// A note names the id of each card that a finding made. When a screen
  /// changes, review its images again and write a new note with the day of
  /// that review. The notes of 2026-10-27 judged images that a stand-in
  /// renderer of the test support drew, with no Liquid Glass, no scroll edge
  /// effect, no mic and Send buttons, and vibrant labels black in dark. Since
  /// ^x7z136m each image is a capture of a real window from the window server
  /// (EditorKit `style.md` rule 9), which shows each of them; a sentence that
  /// named a limit of the renderer names what the image shows, and what a
  /// person still has to judge. Each note keeps the date of its review.
  enum ReviewGalleryNotes {
    /// The day of the first review of every key screen, written `yyyy-MM-dd`.
    static let firstReviewDate = "2026-10-27"

    /// The dated note of `screen`.
    ///
    /// - Parameter screen: The key screen.
    /// - Returns: The note.
    /// - Throws: EditorKit `ReviewGalleryError.invalidNoteDate` when the date
    ///   of the note is not a calendar date.
    static func note(of screen: ReviewGalleryScreen) throws -> ReviewNote {
      try ReviewNote(date: firstReviewDate, note: text(of: screen))
    }

    /// The text of the note of `screen`, with no date.
    ///
    /// - Parameter screen: The key screen.
    /// - Returns: The text.
    static func text(of screen: ReviewGalleryScreen) -> String {
      switch screen {
      case .thread: thread
      case .requestDeck: requestDeck
      case .banners: banners
      case .signIn: signIn
      case .scrolled: scrolled
      case .inspector: inspector
      case .gallery: gallery
      }
    }

    /// The text of the note of ``ReviewGalleryScreen/thread``.
    static let thread = """
      No fill behind the messages, the code block, the terminal output, the tool calls, the plan or \
      the header; each has thin separator edges. The location chip "SearchIndex.swift:2" has the quaternary \
      capsule that AVK-8r allows (text 12.6:1 light, 9.4:1 dark). Findings: the diff text wraps while its \
      gutter and line colors do not, so the lines do not match and the last lines are cut off (^q89x329); \
      the diff counts "+1 −1" are 1.9:1 in light (^a2dy2gt). The "Exit code 0" text was green at 2.2:1 in \
      light; since ^sbx2q4h the green is on the symbol only and the text is the primary label color, at \
      4.5:1 or more in light and dark. Since ^zbcys18 the image \
      draws the glass of the composer and the mic and Send buttons of the accessory row; their look is not \
      judged yet. Since ^fs3vdg0 the diff has no side-by-side file list: the \
      file chip "SearchIndex.swift +1 −1" stands above the patch on the gray selection surface, and the patch \
      takes the full width of the tool call body (DiffViewHostedTests checks the geometry). The new image is \
      not judged yet: the counts on the chip (^a2dy2gt) are to be judged again. Since ^ey6v778 each content \
      tile takes the tile spacing of the theme: the tool calls, the reasoning, the code block, the diff and \
      the terminal output have the tile padding on each edge, the terminal output starts on the leading edge \
      of its header with the tile gap above and below it, the separator under a block header sits in the \
      middle of the gap, and the rows of the transcript have the tile margin between them. The new image is \
      not judged yet. Since ^q89x329 the diff has no soft wrap: each patch line stands on one row, a line \
      wider than the patch scrolls sideways, and the text, the gutter and the line colors keep one row for \
      each line, with the last line inside the diff (DiffLongLineHostedTests checks it at 480 points). The \
      new image is not judged yet. Since step 2 of ^ey6v778 the tile tokens are EditorKit's EditorStyle.tile, \
      which a theme sets (ContentTileThemeHostedTests checks it): the padding and the gap are the same as \
      before, and the tile margin between rows, around and between deck cards and between banners is \
      EditorKit's small spacing step, 8 points, where it was 12; the new images are not judged yet. Since \
      ^7abggb0 the inline diff has one line-number column, as wide as its widest number: a context or an \
      added row shows its new number, a removed row its old number, and every number ends at one right edge \
      beside the +/- marker column (DiffLineNumberHostedTests checks it with a hunk past line 1000). The new \
      image is not judged yet. Since ^tgjr9xg the edit shows its file once: the location chip \
      "SearchIndex.swift:2" is gone, because the diff file chip "SearchIndex.swift +1 −1" names the same file, \
      and the diff is no tile of its own inside the call, so the chip and the patch start on the leading edge \
      of the call body with no second tile padding (ToolCallViewHostedTests checks both). The new image is \
      not judged yet.
      """

    /// The text of the note of ``ReviewGalleryScreen/requestDeck``.
    static let requestDeck = """
      The request cards have no fill. The cards behind the front card show as thin top edges, so \
      the deck reads as a stack ("1 of 2"). The text of the front card is 8.5:1 in light. Since ^zbcys18 the \
      image draws the deck glass, so the bordered buttons on it, glass on glass, and the text of the card over \
      the scrolled list are to be judged again; the recorded request-deck-bar-dark.png (path A) still draws \
      the buttons white. Finding: the pending status symbol of the tool call is 1.9:1 in light and 2.3:1 in \
      dark (^fppqe0q). Since ^ey6v778 the card has the tile padding and the tile gap between its header and \
      its options, and the deck has the tile margin around and between its cards; the new image is not \
      judged yet.
      """

    /// The text of the note of ``ReviewGalleryScreen/banners``.
    static let banners = """
      The connection banner, the three notices, the error entry and the state banner have no \
      fill, only thin edges. The notice symbols use the severity roles (the info role is the system blue, \
      not the accent). Since ^zbcys18 "Show Error" draws its glass and its label in the look of each variant; \
      not judged yet. The "Sent" text was green at 2.2:1 in light; since ^sbx2q4h the green is on the symbol \
      only and the text is the primary label color. Since \
      ^ey6v778 the banners and the error card take the tile padding, and the stacked banners the tile margin \
      between them; the new image is not judged yet.
      """

    /// The text of the note of ``ReviewGalleryScreen/signIn``.
    static let signIn = """
      The sign-in card has no fill; Sign In and Sign Out keep the glass styles in the bar. The \
      attachment chip "Release.zip" has the quaternary fill that AVK-8r allows: name 12.6:1 light and 9.4:1 \
      dark, size 3.8:1 light, the same as secondary text, so no card. Since ^zbcys18 the glass buttons draw \
      their glass and their labels in the look of each variant; not judged yet. Since ^sbx2q4h the "Sent" \
      text is the primary label color, with the green on the symbol only. Since ^ey6v778 the sign-in card \
      takes the tile padding and the tile gap between its title and its rows; the new image is not judged \
      yet.
      """

    /// The text of the note of ``ReviewGalleryScreen/scrolled``.
    static let scrolled = """
      The kit puts no opaque fill behind either bar. The "Scroll to Bottom" pill floats over the \
      rows with no fill of its own. Since ^zbcys18 the image draws the glass of both bars and the scroll edge \
      effect over the rows under them; that look is not judged yet. Since ^sbx2q4h the "Sent" text is the \
      primary label color, with the green on the symbol only.
      """

    /// The text of the note of ``ReviewGalleryScreen/inspector``.
    static let inspector = """
      The thread column has no fill, and the inspector form hides its own background, so the \
      column shows the system inspector background. Since ^zbcys18 the grouped-form rows draw dark with light \
      text in dark (ReviewGalleryScreenTests checks it), as the recorded attachment-inspector-dark.png shows. \
      The QuickLook preview is hidden on purpose. Since ^sbx2q4h the "Exit code 0" text of the terminal \
      output is the primary label color, with the green on the symbol only. Since ^ey6v778 the tiles of the \
      thread column take the tile spacing of the theme; the new image is not judged yet. Since ^tgjr9xg the \
      edit shows its file once, as its diff file chip, with no second tile inside the call, as on the thread \
      screen; the new image is not judged yet.
      """

    /// The text of the note of ``ReviewGalleryScreen/gallery``.
    static let gallery = """
      The sidebar shows the system sidebar background, with no kit fill. The open "Permission \
      request" session shows its pending-request count badge (an AVK-8r chip). Since ^zbcys18 the sidebar \
      rows draw light text on the dark sidebar glass in dark (ReviewGalleryScreenTests checks it); the badge \
      color is not judged yet. The Look popover is not in the image: a popover is its own window that AppKit \
      puts on the screen, and the gallery shows no window (AVK-12). The detail is the resumed permission \
      session, with the partial-history banner (no fill) and the permission card. Since ^ey6v778 the banner \
      and the card take the tile padding and the tile margin; the new image is not judged yet. Since EditorKit \
      ^7wt12an (no SwiftUI List) the session lists and the connection states are lazy stacks with no fill: \
      each row takes the tile padding, the rows the tile margin between them, and no row is selected at \
      rest, so no row shows the selectable surface; the new image is not judged yet.
      """
  }
#endif
