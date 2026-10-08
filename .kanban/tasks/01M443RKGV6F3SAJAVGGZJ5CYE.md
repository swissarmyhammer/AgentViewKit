---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4c68qqrqhxj1zmaejd9s9ck
  text: |-
    Research (implement step):
    - The thread path is still in about 30 source files: ConversationSource, ToolCallSource and TerminalSource have a `.thread`/`.record` case beside the session case; ItemRow has `init(item:)`; ConversationView, MessageActions, AgentCommandTarget, AgentCommandScope, ThreadExporter, AgentAuthView, ActivityIndicator, ReasoningView, ResponseView, UnknownItemView, ErrorView, TerminalView, ToolCallView, TaskListView and StateBanner have thread or record initializers or branches.
    - ToolCallRecord.swift also declares the kit ToolCallStatus, ToolKind, ToolContent and ToolCallLocation. Plan.swift declares PlanEntry. Requests/ declares AuthMethod, PermissionOption, ElicitationResult and more. Task ^71k836q removes the kit value copies. Thus this task deletes the files on the card, and moves each value type that a remaining view still uses to its own file. It deletes a value type only when no remaining code uses it.
    - ThreadError is an @Observable ThreadRecord too. It is not on the card list, but it is part of the record model and it holds a model value, so it goes with the records.
    - The Benchmarks package (separate SwiftPM package) uses StreamingMessage and StreamingCoalescer. Those benchmarks go with the types; ^tjr0bxm adds the SessionModel benchmark.
    - The focus segment kind string "agentThread" of AgentCommandTarget is a text value, not the removed type, so the vocabulary scan does not list `agentThread`.
  timestamp: 2026-10-07T22:03:13.528080+00:00
- actor: claude-code
  id: 01m4cc0xr42vcvj9m2spk5edg6
  text: |-
    ### implement — changed

    The kit session model is removed. Each view binds to `ConnectionModel`, `SessionModel` and the `TranscriptEntry` objects. All subtasks are done.

    **Removed**
    - Model: `AgentThread`, `AgentThreadActions`, `ThreadItem`, `ThreadChange`, `ItemPatch`, `ThreadRecord`, `Message`, `Reasoning`, `UnknownRecord`, `ThreadInfo`, `ToolCallRecord`, `TerminalRecord`, `Plan`, `ThreadError`, `Requests/`.
    - The thread path of the views: `AgentThreadEnvironment`, `ConversationSource`, `ToolCallSource` (now `ToolCallPart` over `ToolCallEntry`), `TerminalSource`, `ThreadMessageItemView`, `ErrorActions`, `ComposerTurn`, `EnvironmentComposerTurn`, the `threadActions` value, and the `actions:` parameter of `AgentThreadView`.
    - `StreamingMessage`, `StreamingCoalescer`, the streaming tail of `ResponseView` and `lazyResponseParagraphs`.
    - Test support: `ThreadFixtures`, `NoopThreadActions`, `threadViewHarness`. `ThreadViewHarness.swift` is now `HostedViewHarness+TextViews.swift`.
    - Benchmarks: the streaming scenarios, the corpus and their baselines. They measured `StreamingMessage`. `Benchmarks/` builds and has no scenario until ^tjr0bxm.

    **Added**
    - `RemovedVocabularyTests`: the removed-symbol scan, the `actions:` call scan, and the `@Observable` allow list (`AccessibilityFocusMover`, `CitationSelection`, `DiffLineSelection`, `ExpandedBlocksStore`, `Entry`, `InspectorSelection`, `ScrollAnchorManager`). They failed before the removal.
    - `DecisionRecordTests`: the host hook section names `terminalAuthRunner` and `agentReconnect`; `required-thread-actions.md` is marked not current. They failed before the record change.
    - `Docs/decisions/acp-client-kit.md`: section "Host hooks".
    - Session ports of the hosted tests: conversation pages, empty state, scroll anchors, the Show Error jump, composer submit and stop, EditorKit editor keys, attachments, suggestions, tool call view, terminal view, agent commands, message actions, diff in a tool call.

    **Notes for the next tasks**
    - ^71k836q: these kit types are now used only by their own tests: `ThreadState` (and the kit `StopReason`), `ConfigOption`, `ConfigValue`, `ContextUsage`, `SlashCommand`, `PatchField`, `WireValueEnum`. I did not delete them, because that card owns them.
    - The reasoning row of an entry shows no in-progress shimmer and no duration. The old thread path showed them from kit timestamps. `ThoughtEntry` has no start or end time. The entry path already showed no duration before this task, so this is not a new gap.

    **Evidence**
    - `swift test`: 1091 tests in 115 suites passed (AgentViewKitTests), and 91 tests in 12 suites passed (PackageStructureTests).
    - `Scripts/check-readme.sh`: passed.
    - `Scripts/test-examples.sh AgentViewKitDemo`: passed.
    - `swift build --package-path Benchmarks`: passed.
    - `periphery scan --retain-public`: no new finding.
  timestamp: 2026-10-07T23:43:48.996456+00:00
- actor: claude-code
  id: 01m4cccjv01apmntm6mnetqsnq
  text: |-
    ### test — green
    - evidence: swift test: 1091 tests in 115 suites passed, 0 failed. Scripts/check-readme.sh: passed (3 snippets compile). Scripts/test-examples.sh AgentViewKitDemo: 4 UI tests, 0 failures, PASS. swift build --package-path Benchmarks: build complete.
    - warnings: only the expected mlx-swift "missing creator for mutated node" and the Xcode "Metadata extraction skipped" notices. No skipped tests. No time-limit failure, so no uptime run.
    - changes: none. Nothing committed.
    - next: review
  timestamp: 2026-10-07T23:50:11.040109+00:00
- actor: claude-code
  id: 01m4cdac0faw244wgpv1kbvjkg
  text: |-
    ### review — findings
    - scope: review sha HEAD~1..HEAD (commit da9fba6). Counts: 3 findings, 3 confirmed, 8 refuted.
    - evidence: Tests/AgentViewKitTests/Terminal/TerminalViewHostedTests.swift:64 (reuse/reuse), Tests/AgentViewKitTests/Thread/ConversationViewHostedTests.swift:67 (completeness/public-output-contract), Tests/PackageStructureTests/RemovedVocabularyTests.swift:184 (completeness/invariant-propagation).
    - check: each finding was checked against the code. `openTerminal`, `openCall` and `sendMessages` are new in this commit (not in HEAD~1), so the rule that drops refactors of old tests does not apply. The `observableClassDeclaration` regex is `@\w+\s+` with no argument list.
    - note: the 235 "found no file" notices of the code-hygiene Swift rules refer to the 47 files that this commit deletes. The task records them as one summary line; they are not findings.
    - next: the implementer corrects the 3 open items. Then run /review again. The same cause (`_ = await waitUntil`) is also in `openTerminal` and `openCall`; correct it in each helper.

    step: review
    outcome: findings
    evidence: 3 findings — Tests/AgentViewKitTests/Terminal/TerminalViewHostedTests.swift:64, Tests/AgentViewKitTests/Thread/ConversationViewHostedTests.swift:67, Tests/PackageStructureTests/RemovedVocabularyTests.swift:184
    task: ^gzj5cye
  timestamp: 2026-10-08T00:06:27.087096+00:00
- actor: claude-code
  id: 01m4cday75yqx1pqbmy6z73kvm
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — 149 files (kit session model removed)
    - test: green — swift test 1091 passed, check-readme passed, test-examples 4 passed, Benchmarks build passed
    - commit: da9fba6
    - review: findings — Tests/AgentViewKitTests/Terminal/TerminalViewHostedTests.swift:64, Tests/AgentViewKitTests/Thread/ConversationViewHostedTests.swift:67, Tests/PackageStructureTests/RemovedVocabularyTests.swift:184
  timestamp: 2026-10-08T00:06:45.733379+00:00
- actor: claude-code
  id: 01m4cedskdevjmbpbz43edhryb
  text: |-
    ### implement — changed

    The 3 review findings are corrected. The card is in `doing`.

    **Finding 1 (reuse): one open-and-wait helper**
    - New file `Tests/AgentViewKitTests/Helpers/ScriptedSessionEntries.swift`. It adds two helpers on `ScriptedSession`:
      - `openWithEntry(update:lookingUp:)` opens a session, sends one update, and waits until the lookup finds the entry. When a step fails, it closes the session before it throws.
      - `receiveEntry(update:lookingUp:)` sends one update on an open session and waits for the entry. The name follows `receivePermissionRequest(id:)` and `receiveElicitation(id:params:)`.
    - `openTerminal` and `openCall` now call `openWithEntry`. The second tool call of `theConnectionChipShowsOnlyForACallThatWaitsForAServer` and `insertMessage` of ConversationViewHostedTests now call `receiveEntry`.

    **Finding 2 (a timeout that the helper ignored)**
    - The helpers now use `try #require(await waitUntil { ... })`, so a timeout stops the test at the point of the loss.
    - Changed: `sendMessages`, `insertMessage` (through `receiveEntry`), `openTerminal`, `openCall`, and the new code of this commit in AgentCommandsTests: `sendTurns`, and three test lines (two pending permissions, the prompt text, three transcript entries).
    - `openSession(messages:)` closes the session when `sendMessages` throws.
    - Not changed: `_ = await waitUntil` in older code that the findings do not name: `ScriptedSessionRequests.swift`, `ThreadMinimapViewHostedTests`, `ThreadExporterTests`, `MessageActionsHostedTests`, `ExpandedBlocksStoreTests`, `RegistryResolutionTests`, `MessageViewsHostedTests`, `WireContentBlockViewHostedTests`, and one line in `AgentCommandsTests` (the plain text test). The rule is: do not refactor older tests that the findings do not name.

    **Finding 3 (attribute with arguments)**
    - RED: I added an assertion to `observableClassNamesFindsTheNameAfterTheAttributesAndModifiers` with `@available(macOS 14, *)` between `@Observable` and `final class Gated`. Before the regex change, it failed: the result was `[]`.
    - GREEN: the pattern is now `(?:@\w+(?:\([^)]*\))?\s+)*`. The doc comment names the argument list. The test passes.

    **Evidence**
    - Filtered run (TerminalViewHostedTests, ToolCallViewHostedTests, ConversationViewHostedTests, AgentCommandsTests, RemovedVocabularyTests): 18 tests passed in 1 suite, and 51 tests passed in 4 suites.
    - `swift test`: 1091 tests passed in 115 suites, 91 tests passed in 12 suites, and 1 test passed in 1 suite. 0 failures. The only warning is the expected mlx-swift "missing creator for mutated node".
    - `Scripts/check-readme.sh`: passed.
    - `Scripts/test-examples.sh AgentViewKitDemo`: 4 UI tests, 0 failures, PASS.
    - There was no time-limit failure, so I did not run `uptime`.

    step: implement
    outcome: changed
    evidence: 6 files — Tests/AgentViewKitTests/Helpers/ScriptedSessionEntries.swift (new), Tests/AgentViewKitTests/Terminal/TerminalViewHostedTests.swift, Tests/AgentViewKitTests/Items/ToolCallViewHostedTests.swift, Tests/AgentViewKitTests/Thread/ConversationViewHostedTests.swift, Tests/AgentViewKitTests/Commands/AgentCommandsTests.swift, Tests/PackageStructureTests/RemovedVocabularyTests.swift; swift test 1091 + 91 + 1 passed
    task: ^gzj5cye
    - next: review
  timestamp: 2026-10-08T00:25:47.885951+00:00
- actor: claude-code
  id: 01m4cer8ncy6gg052xbjfsyw7m
  text: |-
    ### test — green
    - evidence: swift test: 1091 tests in 115 suites passed, 0 failed, 0 skipped. Scripts/check-readme.sh: README gate passed (3 snippets), exit 0. Scripts/test-examples.sh AgentViewKitDemo: 4 UI tests, 0 failures, exit 0. swift build --package-path Benchmarks: build complete, exit 0.
    - warnings seen: only the expected mlx-swift "missing creator for mutated node" line and the Xcode "Metadata extraction skipped, no AppIntents.framework dependency found" line.
    - no time-limit failure. No code changed. Nothing committed.
    - next: review.
  timestamp: 2026-10-08T00:31:30.988853+00:00
depends_on:
- 01M443RA2PMKC5MXXBNH1116AB
- 01M48MQ0BVDHNY798PTF3VYEQH
- 01M48MQDWDPN98ZSWQ4N7S44FW
- 01M48MS20B5GS4711S119KD9GM
- 01M48MSB7741KRK4BVHBGFFCF1
- 01M48MSNZ644ZZQGK3K8YWX4HY
- 01M48MT3CW529Q3MWWN8XRVRW5
- 01M48MTGH4ZSS4GVBP6GVE03AX
- 01M49EX269YQZDGYF6HS3ZYGVH
- 01M49GHXXC7CY7R1PRZ83200VG
- 01M49HGZQP3HMVTY4MC20J25QH
- 01M49HHYXB9KWKB949M0VYZMM0
position_column: doing
position_ordinal: '80'
title: 'Remove the kit session model: AgentThread, ThreadItem, ThreadChange, ItemPatch and the records'
---
## What
The views bind to the client models, so the kit keeps no session state. Source: update.md §4.5 (row 1). The kit copies of the ACP value types are removed in a separate task after this one. Owner rule (2026-10-06): each view binds directly to the observable model of FoundationModelsACPClient (`ConnectionModel`, `SessionModel`, the `TranscriptEntry` objects) and calls the model methods. After this task the kit has no second model, no turn tracking and no copy of model data. The binding tasks that this task depends on move each view group to the models first.

Note (2026-10-07): ^83200vg removed `runTerminalAuth`. The terminal sign-in now uses the `terminalAuthRunner` environment value (`TerminalAuthRunner` of the client), and the Reconnect button uses the `agentReconnect` environment value. ^0vyzmm0 changed the thread view to `AgentThreadView(session:connection:actions:)`.

- [x] Delete from `Sources/AgentViewKit/Model/`: `AgentThread.swift`, `AgentThreadActions.swift`, `ThreadItem.swift`, `ThreadChange.swift`, `ItemPatch.swift`, `ThreadRecord.swift`, `Message.swift`, `Reasoning.swift`, `ToolCallRecord.swift`, `TerminalRecord.swift`, `UnknownRecord.swift`, `Plan.swift`, `ThreadInfo.swift`, `Requests/`.
- [x] Delete the thread path of the views: `Sources/AgentViewKit/Thread/AgentThreadEnvironment.swift` (the `agentThread` value), the `threadActions` value, the `.thread`, `.record` and `.item` cases of `ConversationSource`, `ToolCallSource`, `TerminalSource`, `ItemRow` and `AgentThreadView`, `PendingRequestsHost(thread:)`, `ComposerTurn` and `EnvironmentComposerTurn` (the composer views read the `sessionModel` value and call `prompt(_:meta:)` and `cancel(meta:)` directly), and `PromptQueue.dequeueNext(after:)`.
- [x] Delete `Sources/AgentViewKit/Streaming/StreamingMessage.swift` and `StreamingCoalescer.swift`: the model applies the chunks at display rate, so the kit needs no second coalescer and no copy of the text. Keep `ParagraphSplitter` and `StreamingMarkdownBalancer` as pure functions.
- [x] Remove the `actions:` parameter of `AgentThreadView(session:connection:actions:)`. The only host hooks that stay are the `terminalAuthRunner` and `agentReconnect` environment values, because no model gives that work. Name them in the decision record.
- [x] Rewrite `Sources/AgentViewKitTestSupport/ThreadFixtures.swift`, `ThreadViewHarness.swift` and `NoopThreadActions.swift` on the session test helper (`ScriptedSession`), or delete them. Remove each remaining use of `AgentThread` in `README.md` and `Examples/ReadmeSnippets/Snippets/HostApp.swift`. Run `Scripts/extract-readme-snippets.sh`. Delete or move the tests in `Tests/AgentViewKitTests/Model/` that test the removed types; the merge rules are tested in FoundationModelsACP.
- [x] Add `AgentThread`, `ThreadChange`, `ItemPatch`, `StreamingMessage`, `StreamingCoalescer`, `ComposerTurn` and `isLastWhileRunning` to `RemovedVocabularyTests`.

## Acceptance Criteria
- [x] No file in `Sources/`, `Tests/`, `Examples/` or `README.md` uses `AgentThread`, `ThreadItem`, `ThreadChange`, `ItemPatch`, `StreamingMessage`, `StreamingCoalescer` or `ComposerTurn`.
- [x] Each `@Observable` class in `Sources/AgentViewKit/` holds view state only (open state, scroll position, focus, selection, composer draft); none holds a value that `ConnectionModel`, `SessionModel` or a `TranscriptEntry` object holds.
- [x] `swift test`, `Scripts/check-readme.sh` and `Scripts/test-examples.sh AgentViewKitDemo` pass.
- [x] No code in the kit keeps a list of pending requests: `AgentThread.pendingPermissions` and `pendingElicitations` are gone, and `ThreadAccessibility` and `AgentCommandTarget` read the pending requests of `SessionModel` (moved from ^6a6x9x9).

## Tests
- [x] `RemovedVocabularyTests` fails before the removal and passes after it.
- [x] Add a test in `Tests/PackageStructureTests/RemovedVocabularyTests.swift` that lists the `@Observable` classes of `Sources/AgentViewKit/` and fails on a class that is not in the allowed view-state list.
- [x] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.

## Review Findings (2026-10-07 18:50)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 138 file(s) reviewed, 14 not reviewed.

> 4 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 4 file(s)

> 10 file(s) not reviewed — no validator matched:
> - `Benchmarks/.benchmarkBaselines/AgentViewKitBenchmarks/main/results.json` — no validator matches this file
> - `Benchmarks/Baselines/AgentViewKitBenchmarks.Streaming_chunk,_paragraph_split_off.p90.json` — no validator matches this file
> - `Benchmarks/Baselines/AgentViewKitBenchmarks.Streaming_chunk,_paragraph_split_on.p90.json` — no validator matches this file
> - `Benchmarks/README.md` — no validator matches this file
> - `Docs/decisions/accessibility.md` — no validator matches this file
> - `Docs/decisions/acp-client-kit.md` — no validator matches this file
> - `Docs/decisions/required-thread-actions.md` — no validator matches this file
> - `README.md` — no validator matches this file
> - `Tests/AgentViewKitTests/Items/Fixtures/thread-export.md` — no validator matches this file
> - `plan.md` — no validator matches this file

> 235 tool-rule notices (47 each from `code-hygiene/disallowed-constructs-swift`, `function-length-swift`, `idioms-swift`, `magic-numbers-swift` and `missing-docs-swift`): each rule "found no file" at one of the 47 files that this change deletes, so it could not read that file. These notices are not findings.

- [x] `Tests/AgentViewKitTests/Terminal/TerminalViewHostedTests.swift:64` `reuse/reuse` — `openTerminal` duplicates the open, send, wait, and look-up sequence of `openCall` in ToolCallViewHostedTests. Each file now keeps its own copy of the same scripted-session setup. Share one open-and-wait helper between the two test files, parameterized by the update JSON and the entry lookup, and call it from both `openTerminal` and `openCall`.
- [x] `Tests/AgentViewKitTests/Thread/ConversationViewHostedTests.swift:67` `completeness/public-output-contract` — `sendMessages` discards the result of `waitUntil`, so a timeout is silently ignored. If the model never shows the sent messages, the helper returns normally and the calling test continues with stale state. The error is silenced instead of reported, which the same kind of check flags in product code. Make the helper fail on timeout: `#expect(await waitUntil { session.model.transcript.count == total })`, or have it throw when `waitUntil` returns false, so the test reports the missing messages at the point where they were lost.
- [x] `Tests/PackageStructureTests/RemovedVocabularyTests.swift:184` `completeness/invariant-propagation` — The `observableClassDeclaration` pattern accepts only bare attributes (`@\w+`) between `@Observable` and `class`. The doc comment says other attributes can stand there, but an attribute with arguments, such as `@available(macOS 14, *)`, breaks the match. A class declared that way is silently excluded from the `@Observable` allow-list check. Allow an optional parenthesized argument list after each attribute name, for example `(?:@\w+(?:\([^)]*\))?\s+)*`, and add one assertion with `@available(macOS 14, *)` between `@Observable` and `final class` to the existing test.