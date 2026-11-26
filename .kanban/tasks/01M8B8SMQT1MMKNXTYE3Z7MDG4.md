---
assignees:
- claude-code
position_column: todo
position_ordinal: '8e80'
title: Scroll trace for the EditorKit TextMate scan cache ^m5c23p7
---
Request from editorkit-7a (2026-11-26). The EK spike `spike/textmate-scan-cache` (6d4547b3, base 474081e5 = EK main 44b9f941 + the current batch) keeps the TextMate scan for each document version and grammar on the model. It lands only if the AVK 200-row release scroll trace shows a lower main-thread total than the base.

## What
- [ ] Add two variants to the trace setup in the scratchpad: `trace-variants/5-scan-cache` (EK 6d4547b3) and `trace-variants/6-scan-base` (EK 474081e5), both on the same AVK main. Use the same symlink and path override as variants 1 to 4.
- [ ] Add `trace-variants/7-lane-refresh` (EK `spike/lane-refresh-once` 1306ca8a, EK card ^82dhqxm, request from editorkit-7a on 2026-11-26). Its base is also 474081e5, so variant 6 is the shared base. Send also the LaneCompositorView and EditorCompositorMount inclusive time.
- [ ] Record case A with `scratchpad/run_ek_traces.sh` (VARIANTS for 5 and 6, HITCHES=1, the same rounds as ^hkr4anw) when the machine is quiet.
- [ ] Send editorkit-7a the main-thread totals in the scroll window, the TextMate inclusive time, and the hitches.

## Acceptance Criteria
- [ ] This card has the main-thread total of each variant for each round, and the TextMate inclusive time of each variant.
- [ ] editorkit-7a has the numbers.

## Tests
- [ ] Each trace is a windowed run: send start and end lines to testudoapp-9a, editorkit-7a, kanbanviewkit-1c and snapshotviewkit-bc, and run one at a time.
- [ ] After the runs, `git status` in the main checkout shows no change under `Sources/`.

## Workflow
- A trace run has no code change. Use `/tdd` for any code change. #perf