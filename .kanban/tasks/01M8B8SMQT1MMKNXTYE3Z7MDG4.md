---
assignees:
- claude-code
position_column: done
position_ordinal: '8e80'
title: Scroll trace for the EditorKit TextMate scan cache ^m5c23p7
---
Request from editorkit-7a (2026-11-26). The EK spike `spike/textmate-scan-cache` (6d4547b3, base 474081e5 = EK main 44b9f941 + the current batch) keeps the TextMate scan for each document version and grammar on the model. It lands only if the AVK 200-row release scroll trace shows a lower main-thread total than the base.

## What
- [x] Add two variants to the trace setup in the scratchpad: `trace-variants/5-scan-cache` (EK 6d4547b3) and `trace-variants/6-scan-base` (EK 474081e5), both on the same AVK main. Use the same symlink and path override as variants 1 to 4.
- [x] Add `trace-variants/7-lane-refresh` (EK `spike/lane-refresh-once` 1306ca8a, EK card ^82dhqxm, request from editorkit-7a on 2026-11-26). Its base is also 474081e5, so variant 6 is the shared base. Send also the LaneCompositorView and EditorCompositorMount inclusive time.
- [x] Record case A with `scratchpad/run_ek_traces.sh` (VARIANTS for 5 and 6, HITCHES=1, the same rounds as ^hkr4anw) when the machine is quiet.
- [x] Send editorkit-7a the main-thread totals in the scroll window, the TextMate inclusive time, and the hitches.

## Acceptance Criteria
- [x] This card has the main-thread total of each variant for each round, and the TextMate inclusive time of each variant.
- [x] editorkit-7a has the numbers.

## Tests
- [x] Each trace is a windowed run: send start and end lines to testudoapp-9a, editorkit-7a, kanbanviewkit-1c and snapshotviewkit-bc, and run one at a time.
- [x] After the runs, `git status` in the main checkout shows no change under `Sources/`.

## Workflow
- A trace run has no code change. Use `/tdd` for any code change. #perf

## Results (2026-11-26)

Case A, release with -enable-testing, Time Profiler + Hitches, 15 s scroll, AVK 0f3778df, 3 rounds in the order 5 6 7. A load spike (load average 51) came at the start of round 2. Output: scratchpad/ek-traces-run2.txt.

| Variant | Main-thread ms R1 / R2 / R3 | TextMate ms | LaneCompositorView ms | Hitch sum ms | Max hitch ms |
|---|---|---|---|---|---|
| 5 scan cache 6d4547b3 | 11996 / 11770 / 11609 | 281 / 286 / 276 | 882 / 874 / 860 | 2908 / 3017 / 2958 | 33.3 |
| 6 base 474081e5 | 11985 / 11872 / 11753 | 524 / 525 / 506 | 1107 / 1116 / 1094 | 3108 / 3208 / 3158 | 41.7 to 50.0 |
| 7 lane refresh 1306ca8a | 11765 / 11812 / 11669 | 518 / 524 / 522 | 1025 / 1019 / 1008 | 3183 / 3150 / 3233 | 41.7 to 50.0 |

Sent to editorkit-7a on 2026-11-26.
