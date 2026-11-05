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
- actor: claude-code
  id: 01m6p06knq2mga55nzcb02m8rx
  text: |-
    ### implement — changed
    - evidence: commit 405bbcd2 on worktree-agent-af6f6096c2228e56d (HEAD contains 3cec0af3). 19 files: deleted Sources/AgentViewKitStyle/Diff/DiffFileChip.swift, DiffFileLabel.swift, Sources/AgentViewKitStyle/Chips/ToolCallLocationChips.swift, Sources/AgentViewKit/Items/AgentLocationChipStyle.swift, IntegrationTests Style/DiffFileLabelTests.swift, Style/ToolCallLocationChipsTests.swift; added Sources/AgentViewKit/Items/ToolCallLocationChips.swift (internal), Tests/AgentViewKitTests/Items/ToolCallLocationChipsTests.swift; edited ToolCallView.swift, DiffSummary.swift (changeAccessibilityLabel removed), DiffSummary+Changes.swift, FileDiffOperation+Label.swift (doc only), StylePreviewFixtures.swift, Localizable.xcstrings (`%@ %@ file` removed), DiffStyleTests.swift, DiffSummaryTests.swift, ACPValueBridgeTests.swift, AgentViewKitStyle.docc, ARCHITECTURE.md. DiffView.swift untouched.
    - tests: root `swift test` 971 tests/108 suites + 54/9 passed; `swift test --package-path IntegrationTests` 946 tests/124 suites passed (5 known issues are the by-design FontRoleExpectationsTests negatives); ScreenshotTests `swift build --build-tests` OK. Zero warnings in AVK targets (only mlx-swift "missing creator" build-system warning). All three packages resolved EditorKit main 2b0d42e.
    - deviation: `FileDiff.Operation.label` NOT deleted. AVK no longer reads it, but SVK origin main 3efca23 Sources/SnapshotViewKit/Files/CheckpointFileContent.swift reads `operation.label`; deleting it would break SVK. Owner may delete it after SVK stops reading it.
    - design: ToolCallLocationChipStyle/Configuration/Plain style/env modifier removed with the move (one conformer once internal; ErasedStyle is internal to the style module); chips draw the inspector+scope chip directly.
    - note: first IntegrationTests run got an outside SIGTERM (exit 143) mid-run with no failures; re-run green.
    - next: /review
  timestamp: 2026-11-05T14:01:00.343954+00:00
position_column: done
position_ordinal: ffffffa580
title: Delete DiffFileChip and DiffFileLabel; make ToolCallLocationChips internal now that SVK draws PathChip
---
SnapshotViewKit 3efca23 (^ngpy3hg) draws EK PathChip and no longer uses `DiffFileChip`, `DiffFileLabel` or `ToolCallLocationChips`. KVK, SVK and TestudoApp origin mains have 0 uses of any of the three. AVK already draws EK PathChip and doesn't show DiffFileChip or DiffFileLabel; they were kept only for SVK.

- [x] Re-grep KVK, SVK and TestudoApp origin mains (no truncation, including tests) for the three types
- [x] Delete `Sources/AgentViewKitStyle/Diff/DiffFileChip.swift` and `DiffFileLabel.swift`, their `Counts` and helpers used only by them, DocC entries, tests and previews
- [x] Delete `FileDiff.Operation.label` if nothing else in AVK uses it — checked: kept, because SVK 3efca23 `CheckpointFileContent.swift` reads `operation.label` (see comments)
- [x] `ToolCallLocationChips`: if AVK uses it, make it and its `Location` internal to AVK (move into AgentViewKit if it only lives in AgentViewKitStyle for SVK); else delete it
- [x] Update ARCHITECTURE.md (it says DiffFileChip and DiffFileLabel stay only for SVK)
- [x] Keep changes out of DiffView.swift where possible (^qw7ws1y is changing it)
- [x] Root `swift test` and full IntegrationTests green, zero warnings in AVK targets