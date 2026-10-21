---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5fv4rkwtqb0yyrvkfdxb8p1
  text: |-
    Research (implement step).
    - The thread verbs (AgentCommandVerb) are registered at the thread path by AgentCommandScope, and the item scopes (message, request, tool call) give only a subject (AgentItemScope). The host-mode inspector is outside each thread scope. Thus the attachment commands must be registered by the attachment scope itself, at its own path, with its own CommandSystem when no ambient system exists (the same rule as AgentCommandScope).
    - Plan: a separate public enum AgentAttachmentVerb (ids agent.openAttachment, agent.revealAttachment, agent.shareAttachment, agent.saveAttachment, agent.quickLookAttachment) in a new group AgentCommandGroup.attachment (id agent.attachment). A new scope kind AgentScopeKind.attachment = "agentAttachment", with the Attachment as the subject. The scope is in AgentScopeKind.items, so the context menu of an attachment shows only the attachment verbs.
    - The scope reuses AgentItemScope (focus target, jump target, context menu, commandScope, navVisible) and adds a mount that registers the five definitions at its path, and removes them at teardown.
    - An internal protocol AttachmentFileService runs the verb. The default is a presenter of the scope: NSWorkspace for Open and Reveal, NSSharingServicePicker at the mount view for Share, fileExporter for Save and quickLookPreview for Quick Look. A test gives a recording double through the environment.
    - AttachmentActions buttons dispatch through the registry of the scope. A button is disabled when the verb cannot run for the attachment, and hidden when the host turns off the group.
    - ImageView writes its file at appear (ContentBlockFile gives the same URL for the same bytes), so its scope has a file subject.
    - Existing tests count 13 thread verbs and 4 groups; the group tests change for the new group.
  timestamp: 2026-10-21T18:21:28.572660+00:00
- actor: claude-code
  id: 01m5fw6jr5g5s2r7seehb869nf
  text: |-
    Implementation landed (not committed).
    - New public `AgentAttachmentVerb` (agent.openAttachment, agent.revealAttachment, agent.shareAttachment, agent.saveAttachment, agent.quickLookAttachment): title (the catalog keys Open, Reveal in Finder, Share, Save, Quick Look), icon (SharedSymbol), File menu group `agentAttachment`, context menu group 0, group `AgentCommandGroup.attachment` (id agent.attachment, `attachmentVerbs`). A separate enum keeps the thread verbs (13) and their target unchanged.
    - `AgentScopeKind.attachment = "agentAttachment"`, in `items`, so the context menu of an attachment in a message shows only the five verbs.
    - `AgentAttachmentScope` (Commands/AgentAttachmentScope.swift): adds the segment with the Attachment as subject through `agentItemScope` (focus target, jump label, context menu, navVisible), uses the ambient CommandSystem or its own, and a mount registers the five definitions at its own path. The mount holds the path in `CommandSystem.mountHolders`, so an older view does not remove the commands of a newer view at the same path. A scope inside a scope of the same attachment makes no second scope.
    - Applied on AttachmentView, AttachmentChip (also the composer chips), ImageView, AttachmentInspector and ArtifactView. ImageView now writes its block file when it shows (`ContentBlockFile.url(of:named:)` gives the same URL for the same bytes), so its commands have a file.
    - `AgentAttachmentCommand` reads the attachment with `@FromTarget(kind: agentAttachment)`. Availability: a file URL must point to a file that exists; Reveal, Save and Quick Look need a file URL.
    - Internal `AttachmentFileService` runs the verb; default `AttachmentPresenter` per scope (NSWorkspace; NSSharingServicePicker at the mount view; fileExporter; quickLookPreview). Tests give `RecordingAttachmentFileService` through `\.attachmentFileService`.
    - `AttachmentActions` buttons dispatch through the target of the scope; disabled when the verb cannot run; hidden when the group is off. The ShareLink and the button-only file exporter and Quick Look are gone.
    - Shared `AgentCommandRegistration.register(_ definitions:at:into:groupsOff:)` now serves the thread scope and the attachment scope (no copied loop).
    - PackageStructureTests: `AttachmentPresenter` added to the allowlist of the observable classes (view state only: the open save panel and Quick Look panel).
    - The hosted tests were written after the code; a mutation run without the inspector scope made 3 of them fail (both inspector-mode button tests and the inspector scope test), then the scope was restored.
  timestamp: 2026-10-21T18:39:56.677828+00:00
- actor: claude-code
  id: 01m5fw6qckegs361qe2xy3214s
  text: |-
    ### implement — changed
    - evidence: new Sources/AgentViewKit/Commands/AgentAttachmentCommands.swift, Sources/AgentViewKit/Commands/AgentAttachmentScope.swift, Sources/AgentViewKit/Platform/AttachmentFileService.swift, Tests/AgentViewKitTests/Commands/AgentAttachmentCommandsTests.swift (17 tests), Tests/AgentViewKitTests/Attachments/AttachmentCommandsHostedTests.swift (9 tests), Tests/AgentViewKitTests/Helpers/RecordingAttachmentFileService.swift; changed AgentCommandGroup.swift, AgentCommandPlacement.swift, AgentCommandScope.swift, AttachmentActions.swift, AttachmentChip.swift, AttachmentInspector.swift, AttachmentView.swift, ArtifactView.swift, ImageView.swift, ContentBlockFile.swift, FileExport.swift, Localizable.xcstrings, README.md, AgentCommandGroupTests.swift, RemovedVocabularyTests.swift. Full suite with run-watched.sh (avk11-full2): test-exit=0, 1568 tests in 196 suites passed (3 known issues of the harness self-tests, not new), 190 PackageStructureTests passed, 0 compiler warnings, 0 on-screen test-process windows. Snapshot tests passed, so no PNG changed.
    - next: /review
  timestamp: 2026-10-21T18:40:01.427393+00:00
- actor: claude-code
  id: 01m5fw6yn1m0qe2jpz52xe9vc6
  text: 'Correction to the step record: AgentAttachmentCommandsTests has 15 tests, not 17 (the filtered run gave 21 tests = 15 + the 6 tests of AgentCommandGroupTests).'
  timestamp: 2026-10-21T18:40:08.865485+00:00
- actor: claude-code
  id: 01m5fwgn9wcq3kf0fqv75mvwtv
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (cb14a9d). 6 findings (6 confirmed, 11 refuted). Sources/AgentViewKit/Commands/AgentAttachmentCommands.swift:87, :88, :89, :220; Tests/AgentViewKitTests/Attachments/AttachmentCommandsHostedTests.swift:179; Tests/AgentViewKitTests/Commands/AgentAttachmentCommandsTests.swift:75.
    - next: Correct each open item in the "Review Findings (2026-10-21 13:41)" section. Then do the review again. The task stays in the review column.
  timestamp: 2026-10-21T18:45:26.972728+00:00
- actor: claude-code
  id: 01m5fwh9bsjjbpe3ap24cnv95a
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — AgentAttachmentVerb, agentAttachment scope, AttachmentFileService, AttachmentActions runs the commands
    - test: green — run-watched.sh avk11-full2, 1568 passed (3 known issues), 190 PackageStructureTests passed, 0 warnings; on-screen test windows 0
    - commit: cb14a9d
    - review: findings — AgentAttachmentCommands.swift:87, :88, :89, :220; AttachmentCommandsHostedTests.swift:179; AgentAttachmentCommandsTests.swift:75
  timestamp: 2026-10-21T18:45:47.513688+00:00
- actor: claude-code
  id: 01m5fwxn94y66n5favnpypfbs8
  text: |-
    Review findings of 2026-10-21 13:41 corrected (not committed).
    - Magic numbers (AgentAttachmentCommands.swift, the order of the verbs): the switch with the literals 0 to 4 is gone. The order is now the place of the verb in `allCases` (the cases are in the order of the buttons). The file has no numeric literal now, except `contextMenuGroup = 0`, which is a named `static let`. The test eachVerbIsInTheFileMenuAndTheContextMenuInButtonOrder holds the order.
    - Duplication of perform: new internal `AgentCommandDispatch.perform(_:in:at:payload:)` (Sources/AgentViewKit/Commands/AgentCommandDispatch.swift) has the one guard on the system and the path. AgentAttachmentTarget.perform and AgentCommandTarget.perform both call it. The finding said to keep AgentCommandTarget.swift out of this change; the orchestrator instruction said to make that edit when it is small. The edit is one line in the body of perform, with no change of signature, so no separate task was written. New tests: AgentCommandDispatchTests (3 tests). The first run failed to compile because the type did not exist (RED), the second run passed (GREEN).
    - verbIDs copy: AttachmentCommandsHostedTests has no own verbIDs now. It uses `Commands.verbIDs` (typealias Commands = AgentAttachmentCommandsTests), the one definition.
    - attachment(named:in:) copy: deleted from AgentAttachmentCommandsTests, with its now unused `fileText`. The suite calls `Shared.attachment(named:in:)` (typealias Shared = AttachmentInspectorHostedTests).
    - Tool note: the `files` edit op with `replace_all: true` replaced only one match for each call in this session, so each match took one call.
  timestamp: 2026-10-21T18:52:32.932278+00:00
- actor: claude-code
  id: 01m5fwxs0txen1e71wqj9zr9d8
  text: |-
    ### implement — changed
    - evidence: new Sources/AgentViewKit/Commands/AgentCommandDispatch.swift, Tests/AgentViewKitTests/Commands/AgentCommandDispatchTests.swift (3 tests); changed Sources/AgentViewKit/Commands/AgentAttachmentCommands.swift, Sources/AgentViewKit/Commands/AgentCommandTarget.swift, Tests/AgentViewKitTests/Commands/AgentAttachmentCommandsTests.swift, Tests/AgentViewKitTests/Attachments/AttachmentCommandsHostedTests.swift. Full suite with run-watched.sh (avk11-fix1): build-exit=0, test-exit=0, 1571 tests in 197 suites passed (3 known issues of the harness self-tests, not new), 190 PackageStructureTests passed, 0 compiler warnings (the build log has only the SwiftPM note "missing creator for mutated node" for the mlx-swift_Cmlx bundle, which is not from this code), 0 on-screen test-process windows. All 6 findings checked.
    - next: /review
  timestamp: 2026-10-21T18:52:36.762061+00:00
- actor: claude-code
  id: 01m5fx0hrhh6wbjac9nabgt32c
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (commit fdc4964). 0 findings, 0 confirmed, 0 refuted. 6 files reviewed. All 6 items of the earlier section (2026-10-21 13:41) are checked.
    - next: none. The task moved to done.
  timestamp: 2026-10-21T18:54:07.633741+00:00
- actor: claude-code
  id: 01m5fx0v5y2v92dcj23exnrkg6
  text: |-
    ### finish iteration 2 — clean
    - implement: changed — AgentCommandDispatch shared helper; verb order from allCases; shared test helpers; 6 findings checked
    - test: green — run-watched.sh avk11-fix1, 1571 passed (3 known issues), 190 PackageStructureTests passed, 0 warnings; on-screen test windows 0
    - commit: fdc4964
    - review: clean — 0 findings
  timestamp: 2026-10-21T18:54:17.278322+00:00
position_column: done
position_ordinal: ffffa680
title: AVK-11 Make the attachment actions EditorKit commands in the scope of the attachment (D108)
---
Source: testudoapp-4c, after AVK-10 (^0svs7g7). Rules D108 and D109: each UI action is an EditorKit command that the palette can run.

Problem: the attachment actions Open, Reveal in Finder, Share, Save and Quick Look are plain SwiftUI buttons in `AttachmentActions` (Sources/AgentViewKit/Attachments/AttachmentActions.swift). They are not EditorKit commands, so the palette cannot run them and the context menu does not show them from the command system.

Do:
- Add a scope kind for an attachment, with the kit prefix (D105, for example `agentAttachment`), and give the live attachment as the subject (`.commandScope(segment:subject:)`), as AVK-7b (^bghprs8) did for messages and requests. Add it on each attachment chip, image and the inspector view.
- Add the five commands (Open, Reveal in Finder, Share, Save, Quick Look) as `agent.*` verbs that read the attachment with `@FromTarget`. Put them in a command group (AVK-7e, ^mafqm8q), give each an icon, a title in Localizable.xcstrings, and a menu and context menu placement (AVK-1).
- The buttons in `AttachmentActions`, the context menu and the palette all run the same commands. Remove the button-only actions.
- This works in both inspector modes of AVK-10: `.builtIn` and `.host($selection)` (the host shows `AttachmentInspector` in its own inspector).
- Keep each command available only when it can run (for example Reveal in Finder only for a file URL).

Acceptance:
- Headless tests: each command is in `definitions(at:)` at an `agentAttachment` path, and is not available at other paths; `contextMenuMirror(at:)` shows them; a run of each command does its action on the subject (use test doubles for the workspace and the share/save/Quick Look services, so no real UI opens).
- A hosted test: a press on each button in the inspector runs the command (the recorder of the test double gets the call), in `.builtIn` and in `.host` mode.
- No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-11

## Review Findings (2026-10-21 13:41)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 19 file(s) reviewed, 8 not reviewed.

> 6 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 6 file(s)

> 2 file(s) not reviewed — no validator matched:
> - `README.md` — no validator matches this file
> - `Sources/AgentViewKit/Resources/Localizable.xcstrings` — no validator matches this file

- [x] `Sources/AgentViewKit/Commands/AgentAttachmentCommands.swift:87` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Commands/AgentAttachmentCommands.swift:88` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Commands/AgentAttachmentCommands.swift:89` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Commands/AgentAttachmentCommands.swift:220` `duplication/duplication` — AgentAttachmentTarget.perform copies the body of AgentCommandTarget.perform. Both guard on the system and the path, then call system.registry.perform with the verb id. The copies can drift apart, so a fix to one dispatch path may miss the other. Extract one shared helper that takes the system, the path, the command id and an optional payload, and returns Bool. Call it from both AgentAttachmentTarget.perform and AgentCommandTarget.perform. Do not edit AgentCommandTarget.swift in this change, because it is outside the change. Report that edit as a separate task.
- [x] `Tests/AgentViewKitTests/Attachments/AttachmentCommandsHostedTests.swift:179` `reuse/reuse` — The static var verbIDs repeats the mapping of AgentAttachmentVerb.allCases to ids that AgentAttachmentCommandsTests also defines. The copy in this file is a second implementation of the same derivation. Use one shared definition of the verb ids for both test suites instead of two copies.
- [x] `Tests/AgentViewKitTests/Commands/AgentAttachmentCommandsTests.swift:75` `reuse/reuse` — The static helper attachment(named:in:) rebuilds an attachment from a temporary file. AttachmentInspectorHostedTests already has the same helper, and AttachmentCommandsHostedTests calls it as Shared.attachment(named:in:). This copy duplicates that helper, so a fix to one copy will not reach the other. Delete the copy in AgentAttachmentCommandsTests and call AttachmentInspectorHostedTests.attachment(named:in:), as AttachmentCommandsHostedTests does through its Shared typealias.