---
assignees:
- claude-code
position_column: todo
position_ordinal: c680
title: Make the hosted tests stable when swift test runs suites in parallel
---
## What
In a parallel `swift test` run (the default), some hosted tests fail on some runs. The same tests pass with `swift test --no-parallel` and when their suite runs alone. The failures also occur on 3b9ce9d, before ^y5ra063.

Seen failures:
- `EditorKitPromptEditorHostedTests.aSlashListsTheCommandsAndReturnAcceptsOne`: the completion list does not open after "/" (the editor text is "/" and the editor is the first responder).
- `SessionListViewHostedTests.loadMoreAddsTheSecondPageAndGoesAway`
- `AuthorizationViewHostedTests.aThrownErrorShowsTheMessageAndARetryButton`
- `CheckpointViewHostedTests.aFailedRestoreShowsTheError`

Notes:
- Each `HostedViewHarness` makes its window key at init, so windows of parallel suites take the key status from each other.
- A SwiftUI focus set in `onAppear` (`isFocused = true`) made the EditorKit completion test fail more often. `PermissionView` uses `.defaultFocus` for this reason. `ElicitationView` still sets the focus in `onAppear`.
- The machine was under load (sourcekit-lsp at 100% CPU) during the runs.

## Acceptance Criteria
- [ ] Five parallel `swift test` runs in a row pass with the same test counts.

## Tests
- [ ] Run `swift test` five times and record the result of each run.