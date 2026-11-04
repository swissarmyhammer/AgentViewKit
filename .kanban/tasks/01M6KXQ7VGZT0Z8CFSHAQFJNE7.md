---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6m00ek515zvx0yhcr7d8hfr
  text: |-
    Picked up. The "Blocked" line is obsolete: EK renamed its row to `EditorCompletionRow` (EditorComplete, `CompletionPopup.swift`) on EK origin main at 43628df7.

    Research:
    - AVK's own use of `CompletionRow`: only `PromptCompletionRow` (EditorKitPromptEditor.swift), which feeds `CompletionSuggestionsList` of the prompt editor's menu. Tests reach it through `EditorKitPromptEditor.completionRowIdentifier` (ComposerCompletionRoutesHostedTests, SlashCommandSessionModelTests, FontRoleHostedTests) and AVK's own `CompletionRowTests` (IntegrationTests/Style).
    - EK's `EditorCompletionRow(item: Completion, isSelected:)` covers the look: label (chrome font = ui role, callout) + secondary caption detail, on the shared selection surface, small radius.
    - Gaps of EK's row vs AVK's needs (EK not edited; AVK composes them outside the row): (1) no accessibility identifier, (2) no combined element with label/value, (3) no `.isSelected` trait. (4) EK's row pads its selection surface `.padding(.horizontal, spacing.xs)` itself, i.e. outer padding on the row, unlike AVK's rule-10 row; AVK's list margin becomes vertical-only so the inset is not doubled.
    - Other kits (origin mains): KanbanViewKit 701a93d USES AVK's `CompletionRow` — Sources/KanbanViewKit/Editing/BoardFieldCompletion.swift (row of the board field completion list; also named in KVK ARCHITECTURE.md). SnapshotViewKit be738d5: no use. TestudoApp d2841fc: no use.
    - So AVK's public `CompletionRow` stays (no shim added); remove it after KVK moves BoardFieldCompletion onto `EditorCompletionRow`.
    - The review gallery had no image of the prompt completion list; adding one (GlassSnapshotTests `composer-completion-list`).
    - Build setup: same FieldLabel / liveSymbolEffect fix as the main checkout's in-progress working tree (identical hunks copied for the instructed parts).
  timestamp: 2026-11-04T19:19:09.669442+00:00
position_column: doing
position_ordinal: '8480'
title: Deduplicate AgentViewKitStyle CompletionRow onto EditorKit's EditorCompletionRow
---
**Blocked** on EK renaming its public `CompletionRow` (EditorComplete, made public in df2ba2a9) to `EditorCompletionRow`. editorkit-b5 sends the SHA. Don't start before then.

AgentViewKitStyle has its own public `CompletionRow`. Both are the row of a completion list, and the user's boundary says single-value controls belong to EK. Check whether EK's type covers AVK's uses (EditorKitPromptEditor.swift:624 and the rest). If it does, delete AVK's and adopt EK's. If it doesn't, write on the card what EK is missing and send it to editorkit-b5.

## Acceptance Criteria
- [ ] AVK has no `CompletionRow` of its own, or the card says why it stays.
- [ ] Before pushing the removal, grep the KVK, SVK and Testudo origin mains for `CompletionRow` from AgentViewKitStyle (KVK's BoardFieldCompletion imports both modules), and wait for each user's SHA.
- [ ] The review gallery shows the prompt completion list, light and dark.

## Tests
- [ ] The full AVK test suite is green, with zero warnings in AVK targets.