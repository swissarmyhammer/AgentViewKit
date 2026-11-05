---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6nyqbpg0ar1e6wt1eyj53d1
  text: |-
    Research (HEAD 3cec0af3):
    - Re-grepped origin mains with `git grep FETCH_HEAD` (all paths incl. tests, no truncation): SVK 3efca23, KVK fa69244, TestudoApp 52615e5 have 0 code uses of DiffFileChip, DiffFileLabel, ToolCallLocationChips, ToolCallLocationChipStyle/Configuration, toolCallLocationChipStyle, changeAccessibilityLabel (SVK hits are only in .kanban history).
    - BUT SVK 3efca23 `Sources/SnapshotViewKit/Files/CheckpointFileContent.swift` reads `operation.label` (`case .unknown: operation.label`). So `FileDiff.Operation.label` must stay public in AgentViewKitStyle or SVK breaks. Keeping it; only its doc changes.
    - `DiffSummary.FileSummary.changeAccessibilityLabel` is read in Sources only by DiffFileChip (DiffView draws PathChip and doesn't use it) -> helper used only by the chip -> delete with its 2 tests, its xcstrings entry `%@ %@ file`, and the stale doc in DiffSummary+Changes.swift.
    - ToolCallLocationChips: AVK uses it (ToolCallView, InspectionText). It lived in AgentViewKitStyle only so another kit could draw it with its own ToolCallLocationChipStyle. Moving it into AgentViewKit/Items as internal. The style protocol (ToolCallLocationChipStyle, Configuration, Plain style, env entry, modifier) has one conformer once internal and ErasedStyle is internal to the style module, so the chips draw AVK's inspector/scope chip directly (AgentLocationChipStyle collapses into AgentLocationChip).
    - StylePreviewFixtures.locations/locationLine are used only by the chips preview -> delete.
    - Tests: IntegrationTests Style/DiffFileLabelTests.swift deleted; Style/ToolCallLocationChipsTests.swift: Location.text/id tests move to unit target AgentViewKitTests; style-recording and fittingSize tests go with the style.
  timestamp: 2026-11-05T13:35:12.080807+00:00
position_column: doing
position_ordinal: '9080'
title: Delete DiffFileChip and DiffFileLabel; make ToolCallLocationChips internal now that SVK draws PathChip
---
SnapshotViewKit 3efca23 (^ngpy3hg) draws EK PathChip and no longer uses `DiffFileChip`, `DiffFileLabel` or `ToolCallLocationChips`. KVK, SVK and TestudoApp origin mains have 0 uses of any of the three. AVK already draws EK PathChip and doesn't show DiffFileChip or DiffFileLabel; they were kept only for SVK.

- [ ] Re-grep KVK, SVK and TestudoApp origin mains (no truncation, including tests) for the three types
- [ ] Delete `Sources/AgentViewKitStyle/Diff/DiffFileChip.swift` and `DiffFileLabel.swift`, their `Counts` and helpers used only by them, DocC entries, tests and previews
- [ ] Delete `FileDiff.Operation.label` if nothing else in AVK uses it
- [ ] `ToolCallLocationChips`: if AVK uses it, make it and its `Location` internal to AVK (move into AgentViewKit if it only lives in AgentViewKitStyle for SVK); else delete it
- [ ] Update ARCHITECTURE.md (it says DiffFileChip and DiffFileLabel stay only for SVK)
- [ ] Keep changes out of DiffView.swift where possible (^qw7ws1y is changing it)
- [ ] Root `swift test` and full IntegrationTests green, zero warnings in AVK targets