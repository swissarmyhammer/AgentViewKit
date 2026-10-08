---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4ctcb1e33h1q0809g189v2z
  text: |-
    Research done.
    - plan.md is mostly the old design (AgentThread, three sources, StreamingMessage, schemaName catalog, PromptQueueView, CheckpointView, SubagentTreeView). The new DecisionRecordTests scan makes a name anywhere in plan.md fail, so the rewrite must touch more than the listed sections: §1, §2 takes, §3, §6, §7 sample, §8, §9, §11, §12, §13, §14.
    - plan.md §9 and the README Components list must stay equal (ReadmeCoverageTests). Both list components that are not in Sources: AgentTranscriptView, BranchNavigator, SystemPromptView, StructuredItemView, CompactionMarkerView, SubagentTreeView, PromptQueueView, CheckpointView, AuthorizationView. The built kit has CompactionEntryView, SessionStreamBanner, SessionNoticeBanner, AgentConnectionBanner, AgentInfoHeader, PendingRequestsHost and InProcessAgent.
    - 123 references to update.md are in 93 files (code comments, tests, scripts, records). UpdatePlanNamesTests reads update.md and says to delete it with update.md. To delete update.md with no dangling reference, the model facts of update.md §4.2, §4.3, §4.4 and §4.7 move into plan.md §3, and each comment points to the new plan.md section.
    - connection-states.md describes ConnectionStore, which is removed. The agent connection is ConnectionModel.state (.disconnected, .connecting, .connected, .failed); the MCP server status is MCPServerStatus (.notReported, .connecting, .connected, .failed, .closed).
    - update.md items that are not on the board and not done: §8 item 5 (make the serve/compose helper of FoundationModelsACPAgent public; it is still in the acp-agent executable target) and §9.4 (AgentProcess has only init(command:arguments:); no environment, no currentDirectory, no exit status). §9.3 item 2 was dropped by the owner rule in ^cx8jhpp. The permission comment has no 50 ms wait now (awaits selectPermission).
  timestamp: 2026-10-08T03:54:43.118972+00:00
- actor: claude-code
  id: 01m4cvxyjnnh4q1jgp2aqmssxm
  text: |-
    Implementation landed.
    - `Docs/decisions/acp-client-kit.md`: new section "Binding rule" (the rule, a table of the allowed view state with its kit types, and the host values that stay: `diffActions`, `toolCallConnectionState`, the platform services). The section "Host hooks" now refers to RemovedVocabularyTests for the removed names. The scope record names no removed part as a word.
    - `plan.md`: full rewrite for an ACP client kit. §3 now holds the model facts of the update plan (§3.2 session model, §3.3 connection model, §3.4 verbs, §3.5 in-progress state, §3.6 views per entry kind, §3.7 rules in FoundationModelsACP, §3.8 view tasks, §3.9 the in-process agent). The section numbers that code comments cite keep their topic (§3.6, §8, §9 groups, §11 decision numbers, §12, §13.x).
    - §9 inventory and the README Components list now name only the built components: removed AgentTranscriptView, BranchNavigator, SystemPromptView, StructuredItemView, CompactionMarkerView, SubagentTreeView, PromptQueueView, CheckpointView, AuthorizationView; added CompactionEntryView, SessionStreamBanner, SessionNoticeBanner, PendingRequestsHost, AgentConnectionBanner, AgentInfoHeader.
    - `connection-states.md` rewritten: `ConnectionModel.state` and `MCPServerStatus`. `accessibility.md`, `permission-ux.md`, `required-thread-actions.md`, `acp-version.md`, `attachment-types.md`, `dependencies.md`, `usage-model.md` changed.
    - update.md deleted, with UpdatePlanNamesTests (that suite said to delete it with update.md). A fork retargeted the 120 code-comment references of update.md in about 85 files to the new plan.md sections. New tests guard that the file is gone and that no file cites it.
    - Two update.md items were not on the board: new tasks ^808vyvy (public serve and compose helper of FoundationModelsACPAgent) and ^ma57bws (environment, working directory and exit status of AgentProcess), both tagged blocked-upstream. The other items are done or on ^vewxkf3, ^ckfqs1s, ^26g2qjt. Update plan §9.3 item 2 was dropped by the owner rule in ^cx8jhpp.
    - Not done in this task: `Benchmarks/README.md` still names StreamingMessage in its record section about R1. It is outside the scan scope of the card (Docs/, plan.md, README.md).
  timestamp: 2026-10-08T04:21:48.757007+00:00
- actor: claude-code
  id: 01m4cvy1q8he5jk3068zmd8cvj
  text: |-
    ### implement — changed
    - evidence: RED: `swift test --filter DecisionRecordTests` failed 4 new checks (binding rule heading, update.md deleted, removed part names, update.md citations). GREEN: `swift test --filter "DecisionRecordTests|ReadmeCoverageTests"` 21 tests passed. Full `swift test`: 1021 tests in 110 suites passed, 93 tests in 11 suites passed, 1 test passed; only the expected mlx-swift "missing creator for mutated node" warning. `Scripts/check-readme.sh` passed. `Scripts/test-examples.sh AgentViewKitDemo`: 4 tests, 0 failures, TEST SUCCEEDED. 108 files changed (plan.md, README.md, 9 decision records, DecisionRecordTests.swift, update.md and UpdatePlanNamesTests.swift deleted, comment retargets in Sources, Tests, Benchmarks, Scripts, Package.swift).
    - next: /review
  timestamp: 2026-10-08T04:21:51.976523+00:00
- actor: claude-code
  id: 01m4cw9pmnw4ad6wzejn636mte
  text: |-
    ### test — green
    - evidence: swift test: 1021 tests in 110 suites passed, 0 failed, 0 skipped. Scripts/check-readme.sh: README gate passed (3 snippets). Scripts/test-examples.sh AgentViewKitDemo: 4 UI tests, 0 failures, example gate passed. swift build --package-path Benchmarks: Build complete.
    - warnings: only the expected mlx-swift "missing creator for mutated node" and the Xcode "Metadata extraction skipped" notice.
    - no time-limit failure. No code was changed. Nothing was committed.
    - next: review.
  timestamp: 2026-10-08T04:28:13.845207+00:00
depends_on:
- 01M44449VVAEJBQER0A71K836Q
- 01M443RTQWKFHNWK4SH96PTE46
- 01M443S0EDEB23N7RPAR39TGZ5
position_column: doing
position_ordinal: '80'
title: Rewrite plan.md, the remaining decision records and the README for an ACP client kit
---
## What
Make the documents agree with the built kit. Source: update.md §10 items 1, 3 and 6. Write all text in ASD-STE100 Simplified Technical English. Owner rule (2026-10-06): each kit view binds directly to the observable model of FoundationModelsACPClient (`ConnectionModel`, `SessionModel`, the `TranscriptEntry` objects). A view shows what the model holds and calls the model methods. The kit keeps no parallel state, no copy of model data and no logic that the model owns (turn tracking, turn order, turn-gated queues, pending request lists, connection state, session list, usage or config copies). The documents must state this rule.

- [x] `Docs/decisions/acp-client-kit.md`: add a "Binding rule" section with the rule above, the allowed view state (open state, scroll position, focus, selection, composer draft), and the host closures that stay (for work that no model gives).
- [x] `plan.md`: rewrite §1 (the sources: one ACP client), §3 (the model is `ConnectionModel` and `SessionModel` of FoundationModelsACPClient, bound directly), §11 decisions 1 and 5, §13 (elicitation through the pending requests of the models), §14 R5, R13, R14 and R17. Remove the text about turn summaries, turn-gated queues and kit streaming copies.
- [x] Change `Docs/decisions/required-thread-actions.md`, `accessibility.md` and `permission-ux.md` where they refer to `AgentThread`, the Router, the kit pending requests or kit turn tracking.
- [x] Change `Docs/decisions/connection-states.md`: the agent connection states are `ConnectionModel.state`.
- [x] `README.md`: describe AgentViewKit as the SwiftUI kit for an ACP client that binds to the observable models; list the dependencies; point to the two quick starts. Run `Scripts/check-readme.sh`.
- [x] Remove the `PromptQueueView` line from the README Components list and from plan.md §9 (the owner deleted the queue on 2026-10-06).
- [x] Delete `update.md` when all its items are on the board or done.

## Acceptance Criteria
- [x] No document in `Docs/`, `plan.md` or `README.md` names `AgentThread`, `AgentViewKitRouter`, `AgentViewKitFoundationModels`, `TurnSummary` or `StreamingMessage` as a current part of the kit.
- [x] `Docs/decisions/acp-client-kit.md` has the "Binding rule" section.

## Tests
- [x] Extend `Tests/PackageStructureTests/DecisionRecordTests.swift`: scan `plan.md`, `README.md` and `Docs/decisions/*.md` (except the records marked "not current") and fail on the names `AgentThread`, `AgentViewKitRouter`, `AgentViewKitFoundationModels`, `TurnSummary` and `StreamingMessage`; and fail when `acp-client-kit.md` has no "Binding rule" heading.
- [x] `swift test` and `Scripts/check-readme.sh` pass.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.