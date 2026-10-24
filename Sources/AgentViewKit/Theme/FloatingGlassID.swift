/// The identity of a floating glass of the kit in the glass namespace of its
/// `FloatingGlassContainer` (D113 answer 2).
///
/// The container, `.floatingGlass(id:)` and `.floatingGlassID(_:)` come from
/// the EditorKit `EditorStyle` target. They take any `Hashable` id, so that
/// each kit keeps its own id type. This is the id type of the kit.
///
/// Each glass that shows or hides next to another glass of the same container
/// has an id. The glass next to it has an id too. Then the change morphs, and
/// does not jump.
nonisolated enum FloatingGlassID: Hashable, Sendable {
  /// The field of the composer: the attachment chips and the editor
  /// (`PromptFieldSurface`).
  case composerField

  /// The menu of the editor, which shows and hides above the field of the
  /// composer (``PromptEditorMenuLayer``).
  case editorMenu

  /// The scroll-to-bottom pill, which shows and hides above the composer
  /// (``ScrollToBottomPill``).
  case scrollPill

  /// The suggestion chip at a position in the list. The chips hide while the
  /// agent runs (``SuggestionsView``).
  ///
  /// Two suggestions can have the same text, so the id holds the position of
  /// the chip.
  case suggestion(Int)
}
