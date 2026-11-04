---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6km5d3b78851jsprrpwcbtj
  text: |-
    Unblocked: EditorInspector is on EK origin at f79a6d63 (^tgdjf5g done: feature b5c763b8 + review fixes 725355bb). Run `swift package update` to update all deps together.
    API: `Inspectable: AnyObject, Observable` (`extension X: @retroactive Inspectable`); `Inspection`/`InspectionBuilder`/`FieldGroup`, `FieldBuilder`/`Field` with `.editing .multiline .choices .help .visible .identifier .display`; `Inspection.adding/.removing/.replacing`; `OptionalFieldValue` for the read-only dash. Views: `InspectorView(selection)`, `InspectorView(selection, inspection)`, `InspectorView([any Inspectable])`; `.inspect(_:)` / `.inspect(_:_:)` for the system column. Host switches: `.inspectorScrolling(.host)`, `.inspectorMultipleSelection(.readOnly | .editable)` (read-only default), `.inspectorBlockHeader(.hidden)`. `InspectorForm`, `InspectorActionRow`, `.inspectorPreviewFrame()` are in EK now; drop or re-export AVK's.
    Behavior: each commit is one undo entry; undo re-runs the edit block with the old value, so register no undo of your own. Ids: view id.group.field (e.g. `task.task.title`); a Mixed row reads "Mixed".
    Gotchas: `InspectorView([a, b])` with an array literal is ambiguous, so pass a typed variable. A hosted test bed must install the command system above the window scope, or the window undo stack isn't registered.
    Models: EK Sources/EditorInspector, ScreenshotTests/Tests/ScreenshotTests/InspectorGallery.swift, fixtures `InspectedTask`/`InspectedFile` in EditorTestSupport.
  timestamp: 2026-11-04T15:52:09.067423+00:00
- actor: claude-code
  id: 01m6kmmpcw850a9k1xjg6pxxye
  text: |-
    Scope change (user, relayed by editorkit-b5, 2026-11-04): every kit cuts over to EditorInspector, tests included.
    - Rewrite AVK's inspector tests on EK's scheme and driver instead of keeping their checks: AttachmentInspector hosted tests, InspectorForm/ActionRow/PreviewFrame tests, ConfigOptionsView, ToolToggles. This replaces "existing tests pass unchanged".
    - Drop AVK's own scope paths, ids and accessibility shapes for inspector rows.
    - No AVK forms or editors inside inspectors.
    - EK ^eghwsfh (origin 748bc174, follows ^268hf35) brings: the id scheme `…/inspection:<view>/object:<id>/field:<group>.<label>`; one accessibility element per row (label, value, hint), with `.display` content keeping its own children; `.completions` for text and tag fields; one policy for edits that collide with a model change; `InspectorDriver` in EditorTestSupport (find a field by id, read value and Mixed, edit, commit or cancel, pick a completion, press a display-row button, read a refusal, check the focus wall).
    - Start the cutover on f79a6d63. Move the tests onto InspectorDriver when editorkit-b5 sends the ^eghwsfh SHA.
  timestamp: 2026-11-04T16:00:30.108067+00:00
- actor: claude-code
  id: 01m6kmpyyvd23j5kwwbtmpz9gr
  text: |-
    Picked up. `swift package update` run in root, IntegrationTests/ and ScreenshotTests/: EditorKit resolves at f79a6d6 (EditorInspector present).

    Scope change (user, relayed by editorkit-b5, mid-implement): rewrite AVK's inspector tests on EK's scheme instead of keeping their checks (AttachmentInspector hosted tests, InspectorForm/ActionRow/PreviewFrame tests, ConfigOptionsView, ToolToggles) — replaces "existing tests pass unchanged". Drop AVK's own scope paths/ids/accessibility shapes for inspector rows; use EK's. No AVK forms or editors inside inspectors. EK ^eghwsfh (748bc174, not final) brings the `…/inspection:<view>/object:<id>/field:<group>.<label>` id scheme, one a11y element per row, `.completions`, edit-collision policy and `InspectorDriver`; moving tests onto InspectorDriver waits for its final SHA — no AVK driver copy; write hosted tests so the move is mechanical.

    Research notes:
    - `Attachment` is a struct and `ToolToggle` a value list with a host closure, but `Inspectable`/`InspectorView` need `AnyObject & Observable`, so each needs an observable object to inspect.
    - EK `Inspection` is static per type (`static var inspection`); per-instance groups (agent-defined config options, host tool list) go through `InspectorView(object, inspection)` with an inspection built in the body.
    - EK's picker shows `String(describing:)` of each choice, so a select option's choice needs a CustomStringConvertible value type; grouped choices flatten into one picker.
    - EK read-only rows are `LabeledContent`; a `.display` preview sits beside its label.
    - `InspectorForm(actions:content:)` (no name) is internal in EK; only the named and shell inits are public.
    - `Inspection.groups` is internal, so the fields of a conformance can only be checked hosted.
  timestamp: 2026-11-04T16:01:44.411144+00:00
- actor: claude-code
  id: 01m6knc4y7fekr9zrkf0vfphrn
  text: |-
    User decision (relayed by editorkit-b5, 2026-11-04): inspectors are built from EK's shared field kinds only. EK ^eghwsfh removes `.display { View }` and adds no custom-row escape hatch.
    - Kinds: text, multiline, tags; choice, toggle, number; date/time, duration; status (themed token); references (chips, completion, activate); path/file; paged list/history; preview (inspectorPreviewFrame); action row. Each has one look, one accessibility shape and its own InspectorDriver verbs.
    - AVK puts no AVK view inside an InspectorView. Attachment preview → preview kind; tool status → status kind; ConfigOptionsView → choice + toggle; ToolToggles → toggle.
    - Any part that wraps an AVK view in `.display` waits for the ^eghwsfh SHA.
    - A field that fits no kind goes on the EK card as a kind for EK to add. The EK implementer is surveying AVK's inspectors read-only to confirm the kinds.
  timestamp: 2026-11-04T16:13:18.663101+00:00
- actor: claude-code
  id: 01m6kndga85yqmqf2at0mx5hrc
  text: |-
    Coordinator updates applied:
    - Updated all deps again in root, IntegrationTests/ and ScreenshotTests/: EditorKit now at 50414d62 (^268hf35). EditorInspector and EditorTestSupport did not change between f79a6d63 and 50414d62.
    - User decision (via editorkit-b5): inspectors use only EK's shared field kinds, no AVK view inside an InspectorView, and ^eghwsfh removes `.display`. Because of this I reverted my AttachmentInspector-on-InspectorView draft, which wrapped QuickLookPreview in `.display`. **AttachmentInspector waits for the ^eghwsfh preview kind.** Until then it stays on EK's `InspectorForm`/`InspectorActionRow`/`.inspectorPreviewFrame()` through the re-export, and AttachmentInspector*HostedTests keep their checks; their rewrite waits for the same SHA.
    - Tool status will become the status kind once ^eghwsfh lands. For now ToolCallEntry shows status as read-only text (an existing kind).

    Dropped and why: AVK's InspectorForm/InspectorActionRow copies, plus their tests (AgentViewKitStyleTests/InspectorFormTests, IntegrationTests Style/InspectorActionRowTests, Style/InspectorPreviewFrameTests, Attachments/InspectorFormHostedTests). EK owns and tests these now. AgentViewKitStyle re-exports EditorInspector (`Sources/AgentViewKitStyle/Inspector/EditorInspectorExport.swift`), so SVK/KVK, which use InspectorForm/InspectorActionRow today, keep compiling. They should import EditorInspector themselves when they move over.

    ConfigOptionsView decision: `.form` becomes an `InspectorView(session, inspection)` whose inspection is built from the options in the body: choice rows for selects, toggle rows for booleans. It is not a FieldGroup of `SessionModel.inspection`, because the agent names the options per session and an Inspectable's `inspection` is static per type. Grouped choices flatten into one picker with the text "Name (Group)". The inline/grouped pickers and `groupIdentifier`/`groupIdentifierInfix` are gone.
  timestamp: 2026-11-04T16:14:03.080584+00:00
- actor: claude-code
  id: 01m6knfjwn842gfm7za9ytrmsc
  text: |-
    Boundary (user, relayed by editorkit-b5, 2026-11-04): EK holds single-value field controls (harvested into EditorSwiftUI and wrapped as inspector kinds); compound views stay in the view kits. Everything is themed.
    - EK lifts AVK's file chip, tool and file symbols, and status badge as the start of its path chip and status token, rethemed onto EK tokens. When the ^eghwsfh SHA lands, AVK deletes its copies and adopts EK's. That is part of this card.
    - AttachmentInspector, ConfigOptionsView and ToolToggles are compound views. They stay in AVK, built from EK fields and InspectorView.
  timestamp: 2026-11-04T16:15:11.253700+00:00
- actor: claude-code
  id: 01m6knq580ypaffzy108040dre
  text: |-
    Mappings updated (user via editorkit-b5, 2026-11-04; EK cards on origin at 2524005e). Each AVK field maps to an EK kind, and AVK's own copy is deleted by its adoption card:
    - symbols → EK ^j0562t1 (AVK adoption ^QHZMSH, 01M6KNP4RPM98D5RWP51QHZMSH)
    - file/path chip (DiffFileChip, DiffFileLabel, ToolCallLocationChips, maybe AttachmentChips) → EK ^b6cqtr6 (AVK ^PXBQHX)
    - status token (tool call status, StatusCaptionLabel, maybe ConnectionStatusChip) → EK ^jy64ve7 (AVK ^CQH945)
    - attachment and diff preview → one-value preview, EK ^jn3qmmy (AVK ^E0QW7WS1Y). The compound DiffView stays in AVK.
    - ConfigOptionsView / ToolToggles / PermissionModePicker controls → choice and toggle, EK ^bbffx3s (AVK ^CJCQZV3R4J)
    - timing fields (ToolCallEntry timing, etc.) → number, date and duration, EK ^d2fa1j4 (AVK ^XB69S3D)
    - Changed from before: EK has no references field. Assignee and dependency are compound and stay in KVK; AVK uses no references kind.
    Each inspector field that needs one of these kinds waits for that EK SHA. Everything else proceeds on f79a6d63.
  timestamp: 2026-11-04T16:19:19.424081+00:00
- actor: claude-code
  id: 01m6knqed4dw16396n1b8aa5sv
  text: |-
    Correction to the AVK adoption card ids in the comment above:
    - symbols ^1qhzmsh (01M6KNP4RPM98D5RWP51QHZMSH)
    - path/file chip ^hpxbqhx (01M6KNP99GT8QKXQW2JHPXBQHX)
    - status token ^0cqh945 (01M6KNPD85ZZD3N61150CQH945)
    - one-value preview ^qw7ws1y (01M6KNPGZ52K5GTVVE0QW7WS1Y)
    - choice and toggle ^qzv3r4j (01M6KNPN0NR3GM7MCJCQZV3R4J)
    - number, date and duration ^xb69s3d (01M6KNPRF9ER5XPB9E3XB69S3D)
  timestamp: 2026-11-04T16:19:28.804575+00:00
- actor: claude-code
  id: 01m6kqjb7z19swgtt1sr9fv4ne
  text: 'Sequencing (testudoapp-bf, 2026-11-04): 2386e029 pushed this card''s staged removal of InspectorForm/InspectorActionRow (+ inspectorPreviewFrame) by mistake and broke SVK main 7416cb3 (Sources/SnapshotViewKit/Inspector/ChangesInspector.swift:98, :159), so Testudo couldn''t build. 69856eae restored them; code identical to 38059277. With no shims, the removal must not land on origin until SVK has moved to `import EditorInspector`. snapshotviewkit-45 has been asked for that SHA. Push this card''s removal only after it, then send the AVK SHA to snapshotviewkit-45 and testudoapp-bf.'
  timestamp: 2026-11-04T16:51:38.879652+00:00
- actor: claude-code
  id: 01m6kr0cq6h2pab58190mqm7yc
  text: |-
    Implementation landed (working tree, unstaged; no git add/rm from here on, per the coordinator).

    What changed:
    - Deps: EditorKit 50414d62 in all three packages. `EditorInspector` is linked by the AgentViewKit target, IntegrationTests and ScreenshotTests, plus the demo generator (`Scripts/generate_xcodeproj.rb`). **No re-export**: I dropped my `@_exported import EditorInspector` in AgentViewKitStyle under the coordinator's no-shims rule. AVK files import EditorInspector directly. AVK's InspectorForm/InspectorActionRow/inspectorPreviewFrame copies and their tests are deleted in the working tree. Landing that waits for SVK's move to `import EditorInspector`, and the coordinator sequences the push.
    - ConfigOptionsView `.form` is an `InspectorView(session, inspection)`. `ConfigOptionFields` builds choice rows for selects (`ConfigChoice`, text "Name (Group)" for grouped values) and toggle rows for booleans. Edits go through `startSetConfigOption` with the `requestStartReport`. Row ids: `config-options.<section>.<option>`. The menu style is unchanged apart from dropping the inline paths. `groupIdentifier`/`groupIdentifierInfix` are gone.
    - ToolToggles `.list` is an `InspectorView` of an `@Observable ToolToggleList` that follows the host list, with one toggle row per tool. Ids: `tool-toggles.tools.<id>`.
    - New `Sources/AgentViewKit/Inspection/`: `@retroactive Inspectable` for SessionModel, ConnectionModel, MCPServerItem, ToolCallEntry, TerminalEntry, UserMessageEntry, AgentMessageEntry, ThoughtEntry, SessionMessageEntry, PlanTranscriptEntry, CompactionEntry, ErrorEntry and UnknownEntry. They are read-only and use f79a6d63 kinds only (text, multiline, number, toggle, tags, optional). `InspectionText` and `InspectionLabel` are their helpers. I widened CompactionEntryView.statusLabel, ConnectionRow.label(for:) and ConnectionStatusChip.label(for:) from private to internal so these can reuse them.
    - Demo settings sheet: ConfigOptionsView form takes `.inspectorScrolling(.host)` and `.inspectorBlockHeader(.hidden)`. The demo Xcode build was not run.
    - Gallery: `ScreenshotTests/.../InspectorGallery.swift` and `InspectorGalleryFixtures.swift`, recorded from `recordSnapshots()`. They give 61 subject×width×count images, each Light and Dark. Attachment shows built-in (column) and host (panel narrow/wide, one); every other subject shows narrow/wide × one and Mixed, except config/tools, which are one object.

    Test changes (scope change: rewritten on EK's scheme):
    - Deleted AgentViewKitStyleTests/InspectorFormTests, Style/InspectorActionRowTests, Style/InspectorPreviewFrameTests and Attachments/InspectorFormHostedTests. EK owns and tests these now.
    - ConfigOptionsSessionModelHostedTests: form checks now read EK row ids and values. A change goes through the web toggle row, because the harness cannot choose a SwiftUI pop-up item. The grouped-choice check reads the picker value "Fast One (Fast Models)". `selectingTheCurrentValueSendsNothing` and `changingAToggleSendsABooleanValue` were folded or dropped: the boolean params are now checked in `aChangeSends…`, and the equal-value guard is EK's.
    - ToolTogglesHostedTests list checks use EK row ids and wait for the async commit. SessionEntryRowsHostedTests presses the toggle row.
    - New: ClientModelInspectionHostedTests (live updates for tool call, terminal, agent message, thought, plan and session; fields for error, user message, connection and MCP server), InspectorPanelHostedTests (three inspectors in one 240 pt host-scrolled panel; a toggle commit in a panel), and unit tests ConfigOptionFieldsTests and InspectionTextTests.

    Discovered: main 69856eae with EK 50414d62 does not compile IntegrationTests. `InspectorPreviewFrameTests` reports `ambiguous use of inspectorPreviewFrame()`, because EditorTestSupport brings EditorInspector in. Separately, `ThreadFloatingControlsHostedTests.aStreamedTurnKeepsTheThreadPinnedToTheBottom` fails on clean main with the current deps. That failure is not from this card, and it is filed as ^6y6ydyb.

    EditorKit changes needed (for editorkit-b5): an InspectorDriver choice verb, or any test-support way to pick an item of a picker row; and the kinds already listed under "Waiting on EK ^eghwsfh" in the description. No field needed a kind outside the announced list.
  timestamp: 2026-11-04T16:59:19.142116+00:00
- actor: claude-code
  id: 01m6kr0hmvpwxwxeypa0ntr5rr
  text: |-
    ### implement — stuck
    - evidence: `swift test` 944 + 67 passed (only the allowed mlx warning). `swift test --package-path IntegrationTests` 936 tests, 2 issues, all in ThreadFloatingControlsHostedTests.aStreamedTurnKeepsTheThreadPinnedToTheBottom, which also fails on clean main (^6y6ydyb). `swift test --package-path ScreenshotTests` 20 passed, and the gallery wrote the inspector images. Files: Package.swift, IntegrationTests/Package.swift, ScreenshotTests/Package.swift; Sources/AgentViewKit/{Config/ConfigOptionsView.swift, Config/ConfigOptionFields.swift, Input/ToolToggles.swift, Attachments/AttachmentInspector.swift, Attachments/AttachmentActions.swift, Inspection/*, Items/CompactionEntryView.swift, Connections/ConnectionRow.swift, Connections/ConnectionStatusChip.swift, Resources/Localizable.xcstrings}; AgentViewKitStyle Inspector copies deleted plus docc; tests listed in the previous comment; ARCHITECTURE.md, README.md, demo sheet and generator.
    - next: the open acceptance items wait on EK ^eghwsfh kinds and InspectorDriver: AttachmentInspector on InspectorView (preview kind), status/path/duration rows, the attachment Mixed images, and the move to the driver. Landing the copy removal waits for SVK. ^6y6ydyb is a separate pre-existing failure.
  timestamp: 2026-11-04T16:59:24.187936+00:00
- actor: claude-code
  id: 01m6kr250d8e6vp6k24exv89s1
  text: |-
    ### finish iteration 1 — stuck
    - implement: stuck. Everything that fits the f79a6d63 kinds is built; the rest waits on EK ^eghwsfh kinds and InspectorDriver (see "Waiting on EK ^eghwsfh").
    - test: root swift test 944+67 passed; IntegrationTests 936 tests, 1 failure, which also fails on clean main (^6y6ydyb); ScreenshotTests 20 passed, gallery written.
    - commit: b0f176ae, local only. Not pushed: the removal of InspectorForm/InspectorActionRow/inspectorPreviewFrame waits for snapshotviewkit-45's EditorInspector push.
    - review: not run. The card is incomplete until its blockers land.
    - next: when SVK's SHA arrives, review b0f176ae and push. When ^eghwsfh lands, run /finish again for the waiting items.
  timestamp: 2026-11-04T17:00:16.781029+00:00
- actor: claude-code
  id: 01m6kr2yczgzqavwjnbn0k58k0
  text: |-
    EK ^eghwsfh adds (editorkit-b5, 2026-11-04):
    - InspectorDriver gets a verb that chooses an option in a choice row without opening the pop-up. Restore `selectingTheCurrentValueSendsNothing` on it.
    - The inspector test fixtures and InspectorDriver move to a new EK product, `EditorInspectorTestSupport`; EditorTestSupport stops depending on EditorInspector. At that SHA, link and import `EditorInspectorTestSupport` wherever tests use the driver or the `InspectedTask`/`InspectedFile` fixtures.
  timestamp: 2026-11-04T17:00:42.783393+00:00
- actor: claude-code
  id: 01m6ksjyb0gd4ab86mh3ajrks8
  text: |-
    Review findings for b0f176ae are fixed and ticked in the description's `## Review Findings`. I applied the same cause to the whole file and to the files beside it:
    - Magic numbers: InspectorGallery uses `builtInWidth` and the shared `height`. InspectorGalleryFixtures uses `settleSeconds` → `settleLimit`, plus `pairCount` with `prefix`/`first`/`last`. The same CGSize literal shape also appeared in IntegrationTests Inspection/InspectorPanelHostedTests (`narrowWidth`, `panelHeight`) and ClientModelInspectionHostedTests (`width`, `height`), so I named those too.
    - Reuse: `InspectionText.location(_:)` now calls `ToolCallLocationChips.Location.text(path:line:)`.
    - Duplication: `MessageInspection.inspection(title:content:messageID:extra:)` is the one shape now. User, agent, thought and session messages all use it, with send state, and from/to as the extra fields. The FieldGroup takes a built field list; a closure with `return` skips the builder. Key-path accessors failed the Sendable conversion, so the calls use closures.

    ### implement — changed
    - evidence: `swift test`: 944 + 67 passed. `swift test --package-path IntegrationTests`: 936 tests, 2 issues, both the known ^6y6ydyb failure (ThreadFloatingControlsHostedTests.aStreamedTurnKeepsTheThreadPinnedToTheBottom). Note: that run took 565 s, against 49 s earlier; `runningAndIdleWithNoPromptOpenShowTheStateAndAnnounceNothing` took 514 s but passed. `swift build --build-tests --package-path ScreenshotTests` completes. No capture: the gallery output is unchanged. Files: ScreenshotTests/.../InspectorGallery.swift, InspectorGalleryFixtures.swift; Sources/AgentViewKit/Inspection/InspectionText.swift, TranscriptEntries+Inspectable.swift; IntegrationTests/.../Inspection/InspectorPanelHostedTests.swift, ClientModelInspectionHostedTests.swift.
    - next: review. The card's open items still wait on EK ^eghwsfh and on SVK.
  timestamp: 2026-11-04T17:26:55.584570+00:00
- actor: claude-code
  id: 01m6ksp1ae236x93h924shnkm7
  text: |-
    ### finish iteration 2 — clean
    - implement: changed. 5 review findings fixed in 6 files.
    - test: green apart from the known ^6y6ydyb. Root 944+67 passed; IntegrationTests 936, with 1 known failure.
    - commit: f7d59eb0, on top of b0f176ae.
    - review: clean on b0f176ae..f7d59eb0 (0 findings).
    - pushed: origin/main is at f7d59eb0. SVK be738d5 had already moved off AVK's inspector copies.
    - next: the card stays in doing. When EK ^eghwsfh lands, run /finish again for the "Waiting on EK" items.
  timestamp: 2026-11-04T17:28:36.942098+00:00
position_column: doing
position_ordinal: '80'
title: 'All AVK inspection through EditorKit''s EditorInspector: AttachmentInspector, config and tool forms, ACPClient conformances'
---
Rescoped 2026-11-04 by the user's call (relayed by editorkit-b5): the core inspector and `Inspectable` live in EditorKit, so every kit gets them, and **all inspection in AVK goes through EditorInspector**.

EK card ^tgdjf5g (01M6KG4FZSP41EZ8CDBTGDJF5G, card on EK origin at ec3869b2) builds a new EK product, `EditorInspector`: `Inspectable` (`AnyObject, Observable`), `Inspection`, `FieldGroup`/`Field` with the builders, the modifiers, `.adding`/`.removing`/`.replacing`, `InspectorView(selection)` / `InspectorView(selection, inspection)` (the content of an inspector column or panel; a panel can hold several; it replaces `InspectorForm(inspecting:)`), and `.inspect(_:)` as the convenience for the system column. Editable rows use EK editors (String → SingleLineField, `.multiline()` → EditorView at intrinsic sizing, [String] → TagField). EK starts by lifting AVK's `InspectorForm`, `InspectorActionRow` and `inspectorPreviewFrame()` from `Sources/AgentViewKitStyle/Inspector/`.

**Unblocked:** EditorInspector is on EK origin at f79a6d63, and AVK now builds on EK 50414d62.

## Panel hosting
Testudo's dockable panel shows several objects at once. Every AVK inspector has to work as content in a panel where the **host owns scrolling** (no ScrollView or Form scrolling of its own) and at **narrow widths, about 240 pt**. EK's `InspectorView` handles both. Build each one on it, not around it.

## What
1. Once the EK SHA is on origin, update all dependencies together (`swift package update`). Drop AVK's copies of `InspectorForm`, `InspectorActionRow` and `inspectorPreviewFrame()`, or re-export EK's for a transition. Update the docc page (Sources/AgentViewKitStyle/AgentViewKitStyle.docc/AgentViewKitStyle.md).
2. Move every inspector-style form in AVK onto `InspectorView`. Survey at rescope time:
   - `AttachmentInspector` (Sources/AgentViewKit/Attachments/AttachmentInspector.swift: `.inspector(isPresented:)` and `InspectorForm(name:)` with `.inspectorPreviewFrame()`), `AttachmentActions` (`InspectorActionRow`), `AttachmentInspectorMode`, and the users in AttachmentView, ImageView and AgentThreadView.
   - `ConfigOptionsView` `.form` style (Sources/AgentViewKit/Config/ConfigOptionsView.swift:233, a grouped Form over `SessionModel.configOptions`). Decide whether it becomes a `FieldGroup` in SessionModel's inspection.
   - `ToolToggles` `.list` style (Sources/AgentViewKit/Input/ToolToggles.swift:107, a grouped Form of toggles).
   - Not inspectors, so left as they are: the Elicitation `#Preview` Forms (a request form, previews only) and the demo's `GalleryLookControls` (app chrome). Re-check this list with a grep for `Form {`, `.inspector(` and `LabeledContent` when the card starts.
3. Conform the FoundationModelsACPClient models (SessionModel, ToolCallEntry, TerminalEntry, …) as `extension X: @retroactive Inspectable` in AVK.
4. Add the inspector captures to the review gallery (below).

## Review gallery (user rule, relayed by editorkit-b5)
AVK keeps a screenshot of each inspector in its review gallery (~/Library/Caches/AgentViewKit/screenshot-check/index.html).
- Subjects: AttachmentInspector in each of its modes (AttachmentInspectorMode); ConfigOptionsView; ToolToggles; an inspection of each ACPClient model (SessionModel, ToolCallEntry, TerminalEntry, …).
- Each subject in: Light and Dark × narrow (~240 pt, Testudo's docked panel) and wide × one object, and several objects showing Mixed where the type allows it.
- House rules: gallery images only, no reference PNGs or comparison; the capture package in ScreenshotTests/, run once per batch, local only, never CI; the real on-screen window via ScreenCaptureKit; no pixel or layout assertions.
- Model: EK's `ScreenshotTests/Tests/ScreenshotTests/InspectorGallery.swift` (^tgdjf5g) once it lands.

## Acceptance Criteria
- [x] AVK builds against the EK EditorInspector SHA. No AVK copy of InspectorForm/InspectorActionRow/inspectorPreviewFrame is left, apart from a re-export if one is kept.
- [ ] AttachmentInspector is built on EK's `InspectorView` and looks the same.
- [ ] No inspector-style Form is left in AVK outside EditorInspector (config options and tool toggles included, or a written reason on this card why one stays).
- [ ] Each inspector works as panel content: host-owned scrolling, about 240 pt wide, several in one panel.
- [x] SessionModel, ToolCallEntry, TerminalEntry and the other ACPClient view models conform as `@retroactive Inspectable` in AVK.
- [ ] The review gallery has every subject above in the full Light/Dark × narrow/wide × one/several (Mixed) matrix.

## Tests
- [x] Hosted tests: each ACPClient conformance shows its fields and updates live when the model changes.
- [x] Hosted tests: config options and tool toggles still commit their changes through the new rows.
- [x] Existing attachment, config and tool toggle tests pass. Any change to their checks is written on the card.
- [x] One gallery capture run makes the inspector images.

The SHA does not need relaying to KVK/SVK/Testudo; editorkit-b5 sends it to them.

## Waiting on EK ^eghwsfh (field kinds and InspectorDriver)
Everything that fits the f79a6d63 kinds is built. These items wait for the ^eghwsfh SHA, or for the AVK adoption card named:
- [ ] AttachmentInspector on `InspectorView`: needs the one-value preview kind (^qw7ws1y). Until then it stays on EK's `InspectorForm`/`InspectorActionRow`/`.inspectorPreviewFrame()`, and AttachmentInspector*HostedTests keep their checks.
- [ ] AttachmentInspector several-files (Mixed) gallery images: these need the same preview kind.
- [ ] ToolCallEntry status row: status token (^0cqh945). MCPServerItem status row: status token.
- [ ] Path rows: ToolCallEntry locations, the TerminalEntry working directory, and the SessionModel working and additional directories. They need the path kind (^hpxbqhx).
- [ ] Entry duration row: duration kind (^xb69s3d). Started/Ended show today as optional dates.
- [ ] Choosing a config option in a picker row in hosted tests: no harness can pick an item of a SwiftUI pop-up. Today the tests read the picker value and edit through the toggle row. `selectingTheCurrentValueSendsNothing` was dropped because the equal-value guard is EK's now. It comes back on InspectorDriver's choice verb.
- [ ] Move ClientModelInspectionHostedTests, InspectorPanelHostedTests, ConfigOptionsSessionModelHostedTests (form rows) and ToolTogglesHostedTests (list rows) onto `InspectorDriver` and the `…/inspection:<view>/object:<id>/field:<group>.<label>` ids.
- [ ] Landing the removal of AVK's InspectorForm/InspectorActionRow/inspectorPreviewFrame waits for SVK to move to `import EditorInspector` (the coordinator sequences the push).

## Review Findings (2026-11-04, review of b0f176ae)
- [x] ScreenshotTests/Tests/ScreenshotTests/InspectorGallery.swift:39 code-hygiene/magic-numbers-swift — Magic numbers should be replaced by named constants.
- [x] ScreenshotTests/Tests/ScreenshotTests/InspectorGalleryFixtures.swift:45 code-hygiene/magic-numbers-swift — Magic numbers should be replaced by named constants.
- [x] ScreenshotTests/Tests/ScreenshotTests/InspectorGalleryFixtures.swift:136 code-hygiene/magic-numbers-swift — Magic numbers should be replaced by named constants.
- [x] Sources/AgentViewKit/Inspection/InspectionText.swift:23 reuse — `InspectionText.location(_:)` rebuilds the `<path>` / `<path>:<line>` text that already exists as `ToolCallLocationChips.Location.text(path:line:)`. Call that instead (`ToolCallLocationChips.Location.text(path: location.path.rawValue, line: location.line?.rawValue)`) and drop the local format. If the Style type can't be reached from the Inspection code, move the format into one shared function that both call.
- [x] Sources/AgentViewKit/Inspection/TranscriptEntries+Inspectable.swift:94 duplication — the ThoughtEntry inspection is a verbatim copy of the AgentMessageEntry inspection (lines 80-86), differing only in the title. Extract one helper that takes the title plus the text and id accessors, call it from both, and delete the copy. Have UserMessageEntry use the same helper too, adding its send-state field.