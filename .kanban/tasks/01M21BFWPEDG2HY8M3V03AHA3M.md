---
depends_on:
- 01M21AEPX6A1KRH0TQ0D4QV9CP
- 01M21ACHJYSF8G8R7HY3M70Z7F
position_column: doing
position_ordinal: '8180'
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