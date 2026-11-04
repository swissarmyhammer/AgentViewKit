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
- actor: claude-code
  id: 01m6m0pvnnqb1tb1n9mxgf1k2t
  text: |-
    Implementation landed in worktree agent-a3b11d3d18f086ddc (uncommitted, see blocker).

    Correction to the research comment, item (4): the list margin did NOT become vertical-only. I tried `scrollContentMargins(\.spacing.xs, edges: .vertical)` and reverted it: ComposerCompletionRoutesHostedTests.thePopupSitsAtTheCaret asserts the list's rows start `spacing.xs` past the caret (failed by 3.85 pt with vertical-only margins). The list keeps `scrollContentMargins(\.spacing.xs)` on all edges, so the selection surface sits 2×xs from the menu's leading/trailing edges, the same composition as EK's own CompletionPopup (content padding + the row's own horizontal xs).

    Changes:
    - `PromptCompletionRow` draws `EditorCompletionRow(item:isSelected:)` and adds the combined accessibility element, label, value, `.isSelected` trait and `completionRowIdentifier` outside it.
    - AVK `CompletionRow` stays (KVK uses it); its doc says so (^aqfjne7).
    - Gallery: new GlassSnapshotTests `composer-completion-list` (light + dark): the real composer of a session with two commands, a slash typed into the real editor through a key event, captured once the engine lists both rows. Captured once; images at ~/Library/Caches/AgentViewKit/screenshot-check/snapshots/GlassSnapshotTests/composer-completion-list-{light,dark}.png. Look notes for the reviewer: the menu glass lets the backdrop text show through strongly (pre-existing glass of the menu, not this card).
    - Build setup (identical to the main checkout's in-progress fix): FieldLabel(localized:) / .verbatim labels in Inspection/*.swift, ToolToggles.swift, ConfigOptionFields.swift; InspectionLabel returns FieldLabel; LiveSymbolEffect.swift deleted, EK's liveSymbolEffect(isActive:) used, DocC entries removed, StatusBar/ToolCallView docs and ARCHITECTURE.md updated, `import EditorSwiftUI` in IntegrationTests StatusBarTests.

    BLOCKER: IntegrationTests are not green, for a cause outside this card and outside the two instructed build fixes. EK main changed the inspector's accessibility ids to scheme ids (e.g. `inspection:tool-toggles/object:…/field:tools.search`), so 22 inspector tests fail on old ids such as `tool-toggles.tools.create_issue`, `terminal.terminal.command`, `config-options.uncategorized.web` (ClientModelInspectionHostedTests, ToolTogglesHostedTests, InspectorPanelHostedTests, ConfigOptionsSessionModelHostedTests, SessionEntryRowsHostedTests, …). The main checkout's working tree carries more, uncommitted changes for this (ToolToggles `Inspection(id: listIdentifier, …)`, ConfigOptionsView, and those test files), which were not part of my instructions, so I did not copy them. Not committed, per the "commit when green" instruction.
  timestamp: 2026-11-04T19:31:23.957280+00:00
- actor: claude-code
  id: 01m6m0qapa2q9km319vmmdj3et
  text: |-
    ### implement — stuck
    - evidence: root `swift test` green (944 + 67 tests, 0 AVK warnings). IntegrationTests full run: 936 tests, 24 failed = 22 inspector tests on EK's new scheme-id accessibility ids (outside this card) + ^6y6ydyb (known) + thePopupSitsAtTheCaret (my vertical-only margin; reverted; filtered rerun of the 7 completion/prompt/font-role/StatusBar suites: 54 tests passed). ScreenshotTests: 21 tests passed, gallery written with composer-completion-list light/dark. Files: Sources/AgentViewKit/Input/EditorKitPromptEditor.swift, Sources/AgentViewKitStyle/Completion/CompletionRow.swift, ScreenshotTests/Package.swift, ScreenshotTests/Tests/ScreenshotTests/{CompletionListComposer,GlassSnapshotTests,SnapshotFixtures,ReviewGalleryScreenTests}.swift; build fix: Sources/AgentViewKit/Inspection/{InspectionLabel,ClientModels+Inspectable,TranscriptEntries+Inspectable}.swift, Input/ToolToggles.swift, Config/ConfigOptionFields.swift, Items/ToolCallView.swift, AgentViewKitStyle/Status/StatusBar.swift, AgentViewKitStyle.docc/AgentViewKitStyle.md, ARCHITECTURE.md, IntegrationTests/.../Style/StatusBarTests.swift; deleted Sources/AgentViewKitStyle/Symbols/LiveSymbolEffect.swift. Not committed.
    - next: land the inspector scheme-id test fixes (main checkout's in-progress work), rerun IntegrationTests, then commit on the worktree branch.
  timestamp: 2026-11-04T19:31:39.338026+00:00
- actor: claude-code
  id: 01m6m0rffqf9egv2yb4x20bnq8
  text: 'Orchestrator: the IntegrationTests failures in the worktree are the inspector id scheme work of ^e4857xj, which isn''t on its base yet. Once ^e4857xj is pushed (3b896707, 8a937f69, 3b6d5242), merge main into branch worktree-agent-a3b11d3d18f086ddc, rerun IntegrationTests, then commit and review. The EditorCompletionRow gaps (a11y id, combined element, selected trait, own sideways padding) were sent to editorkit-b5 on 2026-11-04.'
  timestamp: 2026-11-04T19:32:17.015448+00:00
- actor: claude-code
  id: 01m6m1r7dntkv1hdf0d2hj6h19
  text: |-
    ### implement — stuck
    - evidence: merged local main daa111f4 (fast-forward). Re-applied the card's work on top; the 4 build-fix files that conflicted (ToolToggles, ClientModels+Inspectable, InspectionLabel, TranscriptEntries+Inspectable) resolved to main's version. The diff left is the card's 6 files plus the new CompletionListComposer.swift. `swift package update` in all three packages → EditorKit 0cbc4834. IntegrationTests: 938 tests passed, 5 known issues, the 22 inspector-id failures and ^6y6ydyb gone, 0 AVK warnings. Root `swift test`: 1 failure, ViewValueLayoutTests.theStyleHasNoPaddingByte (EditorStyle size 136, 15 uncovered bytes). EK 9495fb06 added a stored `EditorStyle.previewHeight` after the 1-byte `density`, which leaves 7 real padding bytes. That is not from this card; main checkout resolves EK bcce50e4 (before 9495fb06), so it doesn't see this yet. Filed ^81kpa17. Not committed: root not green.
    - next: EK reorders EditorStyle's stored fields (^81kpa17), or the coordinator OKs committing with this one EK-caused failure.
  timestamp: 2026-11-04T19:49:37.333184+00:00
- actor: claude-code
  id: 01m6m1sd0zsfd6xead4j1mshcj
  text: |-
    ### implement — changed
    - evidence: checkpoint commit eee76be0 on branch worktree-agent-a3b11d3d18f086ddc (on top of main daa111f4), 7 files: Sources/AgentViewKit/Input/EditorKitPromptEditor.swift, Sources/AgentViewKitStyle/Completion/CompletionRow.swift, ScreenshotTests/Package.swift, ScreenshotTests/Tests/ScreenshotTests/{CompletionListComposer (new),GlassSnapshotTests,SnapshotFixtures,ReviewGalleryScreenTests}.swift. IntegrationTests 938 passed (5 known issues); root swift test 1 known failure ViewValueLayoutTests.theStyleHasNoPaddingByte, which comes from EditorKit 0cbc4834 (^81kpa17); 0 AVK warnings. Not pushed. The coordinator asked for this checkpoint commit.
    - next: coordinator review; merging to main waits for EK's EditorStyle reorder (^81kpa17).
  timestamp: 2026-11-04T19:50:15.839167+00:00
- actor: claude-code
  id: 01m6m272pb2g4m26prbssqyacb
  text: |-
    ### implement — changed
    - evidence: commit aabf21b0 on worktree-agent-a3b11d3d18f086ddc (after eee76be0). It fixes the review finding at ScreenshotTests/Tests/ScreenshotTests/SnapshotFixtures.swift, code-hygiene/magic-numbers-swift: "Magic numbers should be replaced by named constants." `completionListHeight` is now `composerHeight + EditorKitPromptEditor.completionListMaximumHeight` (140 + 160 = 300), so the image size is unchanged and no recapture is needed. I checked CompletionListComposer.swift myself for magic numbers, missing docs, function length and idioms: it has no literals, every declaration is documented, and both functions are short. Its two stored properties start as valid values that each mount replaces; the type comment documents this. `swift build --build-tests --package-path ScreenshotTests` succeeds with 0 AVK warnings. Not pushed.
    - next: coordinator review; the merge waits for EK's EditorStyle padding fix (^81kpa17).
  timestamp: 2026-11-04T19:57:44.011467+00:00
position_column: doing
position_ordinal: '8480'
title: Deduplicate AgentViewKitStyle CompletionRow onto EditorKit's EditorCompletionRow
---
~~**Blocked** on EK renaming its public `CompletionRow` (EditorComplete, made public in df2ba2a9) to `EditorCompletionRow`. editorkit-b5 sends the SHA. Don't start before then.~~ Obsolete: EK renamed it to `EditorCompletionRow` (EditorComplete, `CompletionPopup.swift`) on EK origin main at 43628df7.

AgentViewKitStyle has its own public `CompletionRow`. Both are the row of a completion list, and the user's boundary says single-value controls belong to EK. Check whether EK's type covers AVK's uses (EditorKitPromptEditor.swift:624 and the rest). If it does, delete AVK's and adopt EK's. If it doesn't, write on the card what EK is missing and send it to editorkit-b5.

## Outcome
- AVK's own completion list (`PromptCompletionRow` in EditorKitPromptEditor.swift) now draws EK's `EditorCompletionRow`.
- AVK's public `CompletionRow` STAYS, because another kit uses it. Users on origin main, for later removal:
  - KanbanViewKit 701a93d — `Sources/KanbanViewKit/Editing/BoardFieldCompletion.swift` (the row of the board field completion list; KVK `ARCHITECTURE.md` also names it).
  - SnapshotViewKit be738d5 — no use. TestudoApp d2841fc — no use.
  - No shim added. Remove AVK's `CompletionRow` (and its `CompletionRowTests`, its DocC entry and its `ARCHITECTURE.md` mention) once KVK moves BoardFieldCompletion onto `EditorCompletionRow`.

## What EK's `EditorCompletionRow` lacks (EK not edited; send to editorkit-b5)
- No accessibility identifier. AVK adds `EditorKitPromptEditor.completionRowIdentifier` outside the row.
- Not one accessibility element: no combined label/value of the label and the detail. AVK adds `.accessibilityElement(children: .combine)`, `.accessibilityLabel`, `.accessibilityValue` outside the row.
- No `.isSelected` accessibility trait for the selected row. AVK adds it outside the row.
- The row pads its own selection surface horizontally (`.padding(.horizontal, spacing.xs)` after `.selectionSurface`), i.e. outer padding on a control (style.md rule 10). With AVK's list margin (`scrollContentMargins(\.spacing.xs)`) the surface now sits 2×xs from the menu's leading and trailing edges, as in EK's own popup.

## Acceptance Criteria
- [x] AVK has no `CompletionRow` of its own, or the card says why it stays. (Stays for KVK, see Outcome.)
- [x] Before pushing the removal, grep the KVK, SVK and Testudo origin mains for `CompletionRow` from AgentViewKitStyle (KVK's BoardFieldCompletion imports both modules), and wait for each user's SHA. (Removal not done: KVK uses it.)
- [x] The review gallery shows the prompt completion list, light and dark. (GlassSnapshotTests `composer-completion-list`.)

## Tests
- [ ] The full AVK test suite is green, with zero warnings in AVK targets.