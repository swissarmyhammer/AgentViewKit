---
comments:
- actor: claude-code
  id: 01m2n4kdpy9f60svwzbya2yxm3
  text: |-
    ### finish iteration 1 — stuck
    - implement: stuck — the task cannot start. The code part needs types that do not exist yet.
    - `PermissionPresentation.order(for:)` and `isSecondary(_:)` need `PermissionOption.Kind`. Task 01M21BD0YVS2J4MD6VXDM317W6 (Pending request types) makes that type. It is in todo.
    - `showsSwitchToAuto(configOptions:)` needs `ConfigOption` and `ConfigOption.Category`. Task 01M21BYFK7KVCKXYXJFCJW7FSM (TerminalRecord and ConfigOption types) makes that type. It is in todo.
    - This task depends only on 01M21A8RWGWE533JR6GQ4DNN06. Add the two tasks above to `depends_on`, then start this task again.
    - test: not run. commit: none. review: not run.
  timestamp: 2026-09-16T12:55:52.798676+00:00
- actor: claude-code
  id: 01m2nh1c8rdab1yjymb4ygdxc8
  text: |-
    Research notes (2026-09-16):
    - The dependencies are done now: `PermissionOption.Kind` (Model/Requests/PermissionRequest.swift) and `ConfigOption.Category` (Model/ConfigOption.swift) exist.
    - `PermissionView` does not exist yet. Task 01M21AK7DBCBMDHK82JY5RA063 makes it and reads `PermissionPresentation`. This task makes only the decision file and `PermissionPresentation`.
    - Claude Code docs: modes `default`, `acceptEdits`, `plan`, `auto`, `dontAsk`, `bypassPermissions`. The Bash prompt adds "Yes, and switch to auto mode" in `default` and `acceptEdits` only, when auto mode is available.
    - Codex docs: `/permissions` presets "Read Only", "Auto", "Full Access"; prompt "Yes, proceed", "Yes, and don't ask again for commands that start with ...", "No, and tell Codex what to do differently"; `approvals_reviewer = "auto_review"`.
    - Cursor docs: run modes Auto-review, Allowlist, Run Everything. The docs give no button labels.
    - No v1 source supplies a directory-scoped grant: ACP has no such kind, the Router has no permission store, and FoundationModelsACPAgent plan.md says it has no remembered allow_always store. Decision: no fifth option in v1. A source-defined kind arrives as `.unknown` and goes last, as a secondary option.
    - Pattern to follow: Docs/decisions/checkpoints.md with CheckpointCapabilitiesTests and the MarkdownTable helper.
  timestamp: 2026-09-16T16:33:12.984563+00:00
- actor: claude-code
  id: 01m2nh69ej8shfvv9d2gmz09md
  text: |-
    ### implement — changed
    - evidence: 5 files — Docs/decisions/permission-ux.md, Sources/AgentViewKit/HumanInTheLoop/PermissionPresentation.swift, Sources/AgentViewKit/Model/ConfigOption.swift (adds `SelectChoices.options`), Tests/AgentViewKitTests/HumanInTheLoop/PermissionPresentationTests.swift, Tests/AgentViewKitTests/Model/ConfigOptionTests.swift. `swift test --filter "PermissionPresentationTests|ConfigOptionTests"`: 39 tests passed.
    - decisions: order allow_once, allow_always, reject_once, reject_always, then unknown kinds (stable). The kept kinds and unknown kinds are secondary. No fifth option in v1. Switch to auto shows when the first `mode` select has an `auto` choice and the current value is not `auto` or `plan`. `autoModeOption(in:)` gives the option for PermissionView to set.
    - next: full test run.
  timestamp: 2026-09-16T16:35:53.938452+00:00
- actor: claude-code
  id: 01m2nhacmbmab98g79ygk2z1ea
  text: |-
    ### finish iteration 2 — clean
    - implement: changed — 5 files (decision file, PermissionPresentation, SelectChoices.options, two test files)
    - test: green — `swift test`: 479 tests in 38 suites and the other targets passed; 0 failures, 0 skipped; only the accepted mlx-swift build warning
    - commit: 4e6e208
    - review: clean — `review sha HEAD~1..HEAD`, 0 findings (7 attempted, 0 failed). The decision .md file has no validator.
  timestamp: 2026-09-16T16:38:08.267250+00:00
depends_on:
- 01M21A8RWGWE533JR6GQ4DNN06
- 01M21BD0YVS2J4MD6VXDM317W6
- 01M21BYFK7KVCKXYXJFCJW7FSM
position_column: done
position_ordinal: '9480'
title: 'Research R8: permission and mode option sets from Claude Code, Cursor, and Codex, mapped to ACP (plan §14)'
---
## What
Settle research R8 from plan.md §14 and record it where the code can check it.

- Survey the permission option sets and permission modes in Claude Code, Cursor, and Codex from their current docs. Record them in `Docs/decisions/permission-ux.md` with URLs and dates.
- Map each product option onto the four ACP `PermissionOptionKind`s and the `mode` config option category. Decide the kit's option order, which options are visually secondary, when "switch to auto" appears, and whether a fifth directory-scoped option exists in v1 and which source supplies it. Write the decision table in the same file.
- Encode the decision: `Sources/AgentViewKit/HumanInTheLoop/PermissionPresentation.swift` with `PermissionPresentation.order(for kinds:)`, `isSecondary(kind)`, and `showsSwitchToAuto(configOptions:)`. `PermissionView` reads these.

## Acceptance Criteria
- [x] `Docs/decisions/permission-ux.md` exists with the survey and the decision table.
- [x] `PermissionPresentation` matches the decision table (a test parses the table rows from the file and compares).

## Tests
- [x] `Tests/AgentViewKitTests/HumanInTheLoop/PermissionPresentationTests.swift`: the decision-file match and the three functions.
- [x] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.