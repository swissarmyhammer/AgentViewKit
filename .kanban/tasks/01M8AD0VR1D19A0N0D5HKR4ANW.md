---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m8b0jag2tbrpvg5t10q20tg6
  text: |-
    ### branches from editorkit-7a
    - ^q41mdew: `spike/caption-layout` 0078a05f, against EK ccba113d (the same base; only the captions are different).
    - ^8vgmyc7: `spike/mount-cache` 20db34ef (base 26d91296 = EK main 44b9f941 + ^kk9k7am), against EK 44b9f941. API: `.editorMountCache(cache)` above the transcript list keeps a realized editor for each model. The next EditorView over the same model uses it again. Use it in the trace run with the AVK live-range placeholder swap in use. Without the trace, the cache does not meet its budget (a remount from the cache costs 0.62–0.77 of a fresh remount, and the budget is < 0.25).
    - send: the main-thread totals of each pair, and the mount hitch frames if the trace has them.
    - next: run when the machine is quiet (no headless test runs in other AVK agents), with start and end lines.
  timestamp: 2026-11-26T04:07:09.058349+00:00
- actor: claude-code
  id: 01m8b4h2yprywzefx4xchys8t5
  text: |-
    ### traces — done (neither spike uses less main-thread time than its base)
    - setup: case A (200 rows shown of 312), release with -enable-testing, Time Profiler + Hitches, 15 s scroll, AVK fe695322, 3 rounds in the order 1 2 3 4. The load average fell from 13 (round 1) to 2.3 (round 3). Script: scratchpad/run_ek_traces.sh. Output: scratchpad/ek-traces-run.txt.
    - ^q41mdew main-thread ms in the scroll, rounds 1/2/3: caption-layout 0078a05f 13477 / 13301 / 12903, base ccba113d 13675 / 13223 / 12773. The difference is within the noise.
    - ^8vgmyc7: mount-cache 20db34ef 13276 / 13210 / 12870, EK main 44b9f941 13458 / 12826 / 12762. The cache is not less than main.
    - hitches in round 3 (count / sum ms): caption-layout 290 / 4133, base 245 / 3617, mount-cache 277 / 3900, main 250 / 3758.
    - sent to editorkit-7a on 2026-11-25.
  timestamp: 2026-11-26T05:16:22.870074+00:00
position_column: done
position_ordinal: ffffffffb280
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