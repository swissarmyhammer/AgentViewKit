---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5pxt000zmr1nnvx0zvhnjnq
  text: |-
    ### dependency (2026-10-24)
    EditorKit filed the shared selection surface as card 01M5PXSJHPTMDTANGXTFN4SP6B. It adds `.selectionSurface(_:radius:)`, the tokens `selectionOpacity` (0.20) and `inactiveSelectionOpacity` (0.08), the `appearsActive` grey fallback and the `.isSelected` trait, and moves the palette and completion rows onto it. It is additive and goes straight to EK main with no hold branch. It is queued behind EK ^b84akwb. Start this card only once that card's commit is on EK main, and record the SHA.
  timestamp: 2026-10-24T12:22:42.432939+00:00
position_column: todo
position_ordinal: a380
title: Draw every selection through the shared EditorStyle selection surface (translucent accent, one code path)
---
The user's rule (2026-10-24): one set of code for selection, smart about transparency, so the selection effects are consistent everywhere.

Three states, each drawn one way:
- Focused (where the keyboard is): the system focus ring that the EditorKit scope beacon draws (`agentItemScope` → `.scopeFocusRing`). An outline only. Unchanged.
- Selected (what is chosen): the accent colour at a fixed low opacity, filled in the item's surface shape, behind the content. Text stays `.primary`, with no white-text swap. Because it's translucent, it blends over clear, glass, a tint or a host fill.
- Selected while the window is not key (`appearsActive == false`): `.primary` at a low opacity, the grey macOS uses for an inactive window.
Selected plus focused is the fill plus the ring.

Depends on an EditorKit card, filed with editorkit-28: a `selectionSurface(_ isSelected:, radius:)` modifier and its two opacity tokens in EditorStyle, shared with KanbanViewKit and EditorKit's own lists. Do not start until that card is on EditorKit main. Record the EditorKit SHA in a comment when you start.

Today's separate drawings to replace:
- `Elicitation/ElicitationLayout.swift` field tabs: a Capsule filled with accent at selectedTabOpacity.
- `Diff/DiffView.swift` file rows: a `.quaternary` fill.
- `Input/EditorKitPromptEditor.swift` completion rows: the system `.selection` fill.
- `Citations/SourcesView.swift` highlighted source: check how it draws.
- Attachments and files that select into the host inspector show no selected state today (see ^fqr901r).

- [ ] Each selection site above uses the shared modifier, with the same corners as its focus ring (`AgentSurfaceCorners`).
- [ ] Attachment and file views show the selected state when the host inspector selection is that file.
- [ ] A structure test forbids accent, `.selection`, `.quaternary` or tint fills used as a selection outside the shared modifier.
- [ ] Hosted tests: selected, inactive-window selected, and selected plus focused each draw the expected layer; text stays `.primary`.
- [ ] Snapshots re-recorded for the changed sites, each one listed.
- [ ] No compatibility shims; transparent backgrounds by default. #avk-8 #cross-repo