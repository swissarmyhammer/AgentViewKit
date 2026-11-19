---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m7rkah5cxq8jrakmqvvcfvta
  text: |-
    Research: `AgentCommandVerb` gets `icon`, `menu`, `contextMenu` and `isVisible(in:)` in AgentCommandPlacement.swift (extension `AgentCommandVerb`). `SideCardVerb.presentation` sits next to its icon, menu and context menu. Thus the new `AgentCommandVerb.presentation` is in AgentCommandPlacement.swift, after `icon`.

    Note: the `dump validators` file for .swift is 630 KB. It is too large to read in one pass. I read the prompt rules (code-hygiene prompt rules, duplication, reuse, swift, test-integrity) and skipped the tool-rule staging text.

    ### implement — changed
    - evidence: Sources/AgentViewKit/Commands/AgentCommandPlacement.swift (new `presentation`), Sources/AgentViewKit/Commands/AgentCommands.swift (`definition(of:for:)` calls `CommandDefinition(verb.presentation, target:isVisible:make:)`; the keys dictionary, the id, title, icon, menu and context menu wiring and the weak-target closure are removed), Tests/AgentViewKitTests/Commands/AgentCommandsTests.swift (4 new tests, 2 of them with 22 arguments each). RED: the new tests did not compile (no member `presentation`). `swift test`: 1399 tests in 164 suites passed, plus 54 tests in 11 suites passed. IntegrationTests and ScreenshotTests: `swift build --build-tests` complete. `swift format lint -s`: no new findings (the findings that stay were there before the change).
    - next: review
  timestamp: 2026-11-19T00:29:22.476942+00:00
- actor: claude-code
  id: 01m7rkdhs8q0m49nr5vy1p3jky
  text: |-
    ### test — green
    - evidence: swift test at the package root. "Test run with 1399 tests in 164 suites passed after 28.855 seconds." "Test run with 54 tests in 11 suites passed after 0.013 seconds." Exit code 0. No test failed. No test was skipped.
    - evidence: swift build --build-tests in IntegrationTests. Build complete. IntegrationTests and ScreenshotTests were not run.
    - evidence: swift format lint -s on the 3 changed Swift files (AgentCommandPlacement.swift, AgentCommands.swift, AgentCommandsTests.swift). 0 findings.
    - next: review.
  timestamp: 2026-11-19T00:31:01.416342+00:00
- actor: claude-code
  id: 01m7rkjeyvaajk2svxvm1d2s9k
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (493e3238). 0 findings, 0 confirmed, 0 refuted. 7 pairs attempted, 0 failed. 3 files reviewed. 2 .kanban files not reviewed (.reviewignore).
    - next: none. The task moved to done.
  timestamp: 2026-11-19T00:33:42.363281+00:00
- actor: claude-code
  id: 01m7rkjwdwvtp4arkcdz1v1b4a
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — AgentCommandPlacement.swift, AgentCommands.swift, AgentCommandsTests.swift
    - test: green — swift test, 1399 tests in 164 suites + 54 tests in 11 suites passed
    - commit: 493e3238
    - review: clean — 0 findings
  timestamp: 2026-11-19T00:33:56.156734+00:00
position_column: done
position_ordinal: fffffff880
title: Build the AgentCommand definition through the shared AgentCommandPresentation helper
---
Origin: review finding of ^xf6j8gk (duplication, SideCardCommands.swift). That task added `AgentCommandPresentation` and `CommandDefinition.init(_:target:isVisible:make:)` in Sources/AgentViewKit/Commands/AgentCommandPresentation.swift. `SideCardCommand.definition(of:for:)` and `AgentAttachmentCommand.definition(of:for:)` now use the helper. The finding said not to edit AgentCommands.swift in that task.

Do:
- Add `var presentation: AgentCommandPresentation` to `AgentCommandVerb`, with the key `AgentKeymap.defaultChords[verb]?.first`.
- Make `AgentCommand.definition(of:for:)` in Sources/AgentViewKit/Commands/AgentCommands.swift call `CommandDefinition(verb.presentation, target: target, isVisible: { verb.isVisible(in: $0) }) { target, payload in AgentCommand(verb: verb, target: target, payload: payload) }`.
- Remove the copy of the keys dictionary, the id, title, icon, menu and context menu wiring, and the weak-target make closure.

Tests: the existing AgentCommandsTests (`theDefinitionsCarryTheDefaultKeys` and the others) stay green. Run only `swift test` at the package root.