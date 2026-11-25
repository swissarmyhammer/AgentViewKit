---
assignees:
- claude-code
position_column: todo
position_ordinal: '8980'
title: Scroll traces for the EditorKit perf cards ^q41mdew, ^8vgmyc7 and ^59ykv6h
---
Request from editorkit-7a (2026-11-25). EditorKit decides three perf cards from the AVK scroll trace: the 200-row transcript, a release build, and the main-thread total against EK main. The `.safeAreaBar` fix (4ea3642f) is in each run.

## What
- [ ] ^q41mdew (adaptive captions with no ViewThatFits): when editorkit-7a sends the EK branch name, record the trace with that branch and with EK main. Use the profile harness in the scratchpad (`ScrollProfile`, case A).
- [ ] ^8vgmyc7 (`.editorMountCache`) and ^59ykv6h (geometry one time): when editorkit-7a sends those branch names (after EK ^m0ntdb1), record the trace with each branch and with EK main.
- [ ] Send the main-thread totals to editorkit-7a. Record them on this card.

## Acceptance Criteria
- [ ] For each branch, the card has the main-thread total of the branch and of EK main, from the same build mode and the same transcript.
- [ ] editorkit-7a has the totals.

## Tests
- [ ] Each trace is a windowed run: send start and end lines to testudoapp-9a, editorkit-7a, kanbanviewkit-1c and snapshotviewkit-bc, and run one at a time.
- [ ] After the runs, `git status` shows no change under `Sources/` or `Package.resolved` (the EK branch pin is local to the profile run).

## Workflow
- Use `/tdd` for any code change. A trace run has no code change. #perf