---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m7sy7hh0a0r16z609tvh9e9t
  text: 'Research note (2026-11-19, EditorKit 8a5a1c2f): EditorKit has a find session value `SearchState` (Sources/EditorText/Search/Search.swift: `query`, `options`, `matches: [EditorRange]` in document order, `currentMatchIndex`) and a `SearchDecorations` projection that draws the matches and the current match. Emacs isearch uses the same decorations. `SearchOptions` has caseSensitive, wholeWord and regex, but no diacritic-insensitive option and no "start of word" option. Possible way: AVK computes the match ranges itself (no case, no diacritics, at the start of a word) and gives them to the EditorModel of each hit entry as its search matches (look for `SetSearchResultsEffect` or a public setter), with the current hit as `currentMatchIndex`. Check that the decoration color is the find highlight of the theme (D110 (e)). The whole-entry mark of a semantic hit can be a SwiftUI background on the row. If no public setter exists, ask editorkit-7a for one.'
  timestamp: 2026-11-19T12:59:13.312583+00:00
position_column: todo
position_ordinal: '80'
title: 'Transcript search hits: reveal the best hit and mark the matched words (D207 f)'
---
Brief: /Users/wballard/github/swissarmyhammer/.briefs/search/avk-brief.md and overview.md (testudoapp-9a, D207, TestudoApp commit ba585e0). Read D207, D108, D110, D133, D137 and D193 in TestudoApp/features/decisions.md.

Blocked: this task waits for FoundationModelsACPClient `SessionModel.entry(forWireID:)` on main. On 2026-11-19 ACPClient main is fed61b9, with no lookup. Send the API proposal to testudoapp-9a before the first push (sent 2026-11-19, see the comments).

Do:
- Public values `TranscriptSearchHit` (the wire id of its entry and its matched words `terms`; empty terms for a hit that only cosine found) and `TranscriptSearchHits` (the ordered list, best first). The host gives them to the thread with `.transcriptSearchHits(_:)` (a binding, so that the kit can clear them, see the commands task).
- Reveal: when the hits change, the thread scrolls to the entry of the first hit through `entry(forWireID:)` and the row key (`ConversationView.scroll(to:)`, `ScrollAnchorTarget.item`). It loads more pages when the row is not loaded. A wire id with no entry is skipped.
- Marks: in the entry of each hit, each match of a word of its `terms` (no case, no diacritics, at the start of a word) has the find highlight of the theme (`\.editorTheme`, D110 (e)), not glass. A hit with no terms marks the whole entry with the same color at a low opacity. The current hit has the stronger mark. A collapsed tool call that is the current hit opens.
- Use EditorKit marks or decorations for text in an EditorView. Ask editorkit-7a for a hook if EditorKit has none.

Tests (unit, no window): reveal goes to the first hit, also on a row that is not loaded yet; the marks of a word with case and diacritics; the whole-entry mark for a hit with no terms; a wire id that the model does not have.

Push when `swift test` is green, and send the sha to testudoapp-9a.