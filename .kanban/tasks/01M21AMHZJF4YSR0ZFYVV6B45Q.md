---
comments:
- actor: claude-code
  id: 01m2p2011qnfcv3e6ysc8xxqg9
  text: 'Blocked: this task must make `ToolCallView` route `ToolContent.diff` to `DiffView`. `ToolCallView` is not in the tree. Task ^rmrtrty (01M21AHYBMNR7CNDZRPMWRTRTY) creates it and is in todo. Thus I added ^rmrtrty to depends_on. The graph has no cycle.'
  timestamp: 2026-09-16T21:29:34.519349+00:00
depends_on:
- 01M21AEPX6A1KRH0TQ0D4QV9CP
- 01M21BCRF2JZ6W49NKXHE8KKT1
- 01M21AHYBMNR7CNDZRPMWRTRTY
position_column: doing
position_ordinal: '8180'
title: 'DiffView chrome: file list with counts, hunk actions, attach lines to prompt, over an empty DiffRendererSlot (plan §4.1, §9 C, §11#12)'
---
## What
Create `Sources/AgentViewKit/Diff/DiffView.swift`, `DiffSummary.swift`, and `DiffRendererSlot.swift`, per plan.md §4.1 and decision 12.

Diff rendering is an EditorKit capability, specified in `../EditorKit/diff_plan.md`. The kit builds no stand-in renderer. This task builds the chrome around a renderer slot that has no default; the R3 follow-through task installs EditorKit's view when it ships.

- `DiffSummary.parse(gitPatch:) -> [FileSummary]` with path, operation, and added and removed counts, from the `+`, `-`, and header lines. Counts only; the real parser is EditorKit's.
- `DiffRendererSlot`: an environment value `((patch: String, file: String?) -> AnyView)?`, set with `.diffRenderer { … }`. With no renderer installed, `DiffView` shows a placeholder row with identifier `diff-renderer-missing` and the text "Diff renderer not installed".
- `DiffView(patch:)`: a per-file list with counts on the left (or on top when narrow), identifier `diff-file-<path>`; the renderer for the selected file; per-hunk Accept and Reject buttons (`diff-accept-<index>`, `diff-reject-<index>`) that call host closures `onAccept(file, hunkIndex)` and `onReject`; and "Attach to prompt" (`diff-attach`) that passes the selected lines to a host closure.
- `ToolCallView` routes `ToolContent.diff` here.
- Accessibility label "<language> diff, +A −R".

## Acceptance Criteria
- [ ] `DiffSummary.parse` on a two-file patch gives two summaries with correct counts.
- [ ] With no renderer, `diff-renderer-missing` is present; with a test renderer installed through `.diffRenderer`, the test view is present and the placeholder is absent.
- [ ] A press on `diff-file-<path>` passes that file to the renderer.
- [ ] A press on `diff-accept-1` calls `onAccept` with the file and index 1.

## Tests
- [ ] `Tests/AgentViewKitTests/Diff/DiffSummaryTests.swift`: counts on fixtures with add, delete, modify, and rename.
- [ ] `Tests/AgentViewKitTests/Diff/DiffViewHostedTests.swift`: placeholder, slot, selection, and the action closures.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.