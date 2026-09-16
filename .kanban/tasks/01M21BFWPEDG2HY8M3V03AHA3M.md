---
comments:
- actor: claude-code
  id: 01m2nzym958m113zamt4af52cc
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — added Sources/AgentViewKit/Content/CommandOutputView.swift and Sources/AgentViewKit/Code/OwnModelSlot.swift. CodeBlockView and CommandOutputView now share OwnModelSlot and EditorModel.syncReadOnly(to:).
    - decisions: the default row limit is 200 rows (`CommandOutputView.defaultRowLimit`), and the host can set it with `rowLimit:`. The capped view shows the last rows. Copy writes the full output. The footer value is "Succeeded" or "Failed"; the tint comes from `AgentTheme.StatusColors.color(for: CommandOutputView.ExitOutcome)`. A nil exit code shows no footer.
    - test: green — `timeout 900 swift test --filter AgentViewKitTests`, 721 tests in 63 suites passed, exit 0
    - commit: 15ca6f3
    - review: clean — review sha HEAD~1..HEAD, 0 findings (2 refuted)
  timestamp: 2026-09-16T20:53:51.525135+00:00
depends_on:
- 01M21AEPX6A1KRH0TQ0D4QV9CP
- 01M21ACHJYSF8G8R7HY3M70Z7F
position_column: done
position_ordinal: a680
title: CommandOutputView for shell and job output blocks (plan §9 F)
---
## What
Create `Sources/AgentViewKit/Content/CommandOutputView.swift`, per plan.md §9 F. This is the view for command output that arrives as a text block with a command label, not as an agent-owned terminal. Tool outputs from `execute` kind tools without a `terminalId` route here.

- `CommandOutputView(command: String?, output: String, exitCode: Int?)`: a header with the command in SF Mono and a Copy button, the output in a read-only EditorKit `EditorView` with `.editorSizingMode(.intrinsic)`, capped at a configurable row count with "show all", and a footer with the exit code tinted by success or failure.
- Long output: the view keeps the last N rows visible by default and offers "show all".
- Accessibility label "Command output, exit <code>".

## Acceptance Criteria
- [x] A 500-line output shows the cap and "show all" expands it.
- [x] Exit code 0 tints success; 1 tints failure; nil shows no footer.
- [x] Copy puts the output on the pasteboard.

## Tests
- [x] `Tests/AgentViewKitTests/Content/CommandOutputViewHostedTests.swift`: cap, footer, copy through `FakePasteboard`.
- [x] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.