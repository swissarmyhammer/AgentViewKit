---
assignees:
- claude-code
position_column: done
position_ordinal: '8180'
title: Scroll trace for the EditorKit remount geometry spike ^59ykv6h
---
Request from editorkit-7a (2026-11-26). The EK spike `spike/remount-geometry-once` (345b6d5d, base a4bfc1dc, EK card ^59ykv6h) waits for a width before the first remount refresh. It lands only if the AVK 200-row release scroll trace shows a lower main-thread total than the base.

## What
- [x] Add `trace-variants/8-remount-once` (EK 345b6d5d) and `trace-variants/9-remount-base` (EK a4bfc1dc), both on the same AVK main, with the same method as variants 1 to 7.
- [x] Record case A with `scratchpad/run_ek_traces.sh` (VARIANTS="8 9", HITCHES=1, REPEATS=3) when the machine is quiet.
- [x] Send editorkit-7a the main-thread totals, the EditorCompositorMount and LaneCompositorView inclusive time, and the hitches.

## Acceptance Criteria
- [x] This card has the main-thread total of each variant for each round.
- [x] editorkit-7a has the numbers.

## Tests
- [x] Each trace is a windowed run: send start and end lines to testudoapp-9a, editorkit-7a, kanbanviewkit-1c and snapshotviewkit-bc, and run one at a time.
- [x] After the runs, `git status` in the main checkout shows no change under `Sources/`.

## Workflow
- A trace run has no code change. Use `/tdd` for any code change. #perf

## Results (2026-11-26)

Case A, release with -enable-testing, Time Profiler + Hitches, 15 s scroll, AVK 23ce9256, 3 rounds in the order 8 9. The load fell from 11.6 to 3.7. Output: scratchpad/ek-traces-run3.txt.

| Variant | Main-thread ms R1 / R2 / R3 | EditorCompositorMount ms | Hitch sum ms |
|---|---|---|---|
| 8 remount-once 345b6d5d | 12287 / 11701 / 11656 | 922 / 915 / 886 | 3108 / 2950 / 2908 |
| 9 base a4bfc1dc | 12058 / 11612 / 11782 | 1034 / 1015 / 983 | 3183 / 3100 / 2958 |

The main-thread total is not lower in 2 of 3 rounds (+229 / +89 / -126 ms). Sent to editorkit-7a on 2026-11-26.
