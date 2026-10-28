---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m621jdaccfx6295k3w0gh39f
  text: |-
    ### implement — no-change (cause found outside AVK)
    - Cause: an EditorKit subagent on ^p9rqatc (agent-a128f60eca6a6f642) ran `pkill -f swiftpm-testing-helper; pkill -f 'lldb -b'; ...` at 10:56:04.849 local. AVK's PackageStructureTests helper (pid 17976) exited 55 ms later. Sending SIGTERM or SIGKILL to the helper by hand reproduces the exact symptom: no summary, "reported failures", exit 1. Swift 6.4 doesn't report the signal for Swift Testing targets.
    - Reproduction: 0 of 4 runs (3 full runs, plus 1 with PackageStructureTests and AgentViewKitTests in parallel), all exit 0.
    - Ruled out: in-repo writers under the scanned paths, the repo's own kill commands, large stdout, and RemovedVocabularyTests parallelism (its two scans just finish last, at about 31 and 34 s).
    - Fix: an agent rule, not code. Never pkill/killall swiftpm-testing-helper, xctest, swift-test, lldb or xcodebuild by name; kill only pids your own run started. editorkit-40 has adopted it and recorded it on ^p9rqatc; kanbanviewkit-55 and testudoapp-40 have been told. The user may want it in the shared agent instructions.
    - "Ten full runs in a row": open, to check over the next runs. Every main run since (4 so far) exited 0.
    - If it happens again, capture the full swift test log under a unique name, the system log around the exit (`log show` for the pid), and any pkill/killall in the agent transcripts at that time.
  timestamp: 2026-10-28T20:00:06.988729+00:00
position_column: todo
position_ordinal: b280
title: A full swift test run sometimes ends the PackageStructureTests process with no summary and exit 1, though no test failed
---
Seen in the wt/banner worktree on 2026-10-28. A full `swift test` under the UI-test lock exited 1 with "PackageStructureTests reported failures". No test failed: the process's output stopped partway through `RemovedVocabularyTests` and never printed a summary, and there was no crash report. `swift test --filter PackageStructureTests` alone passed (274 tests), and a second full run with no code change was green.

## Work
- [ ] Reproduce it by repeating the full `swift test` under the lock until it fails, or by running PackageStructureTests in parallel with the other targets the way swift test does. Record the frequency.
- [ ] Find the cause. Candidates: a scanner reading a file that another target's test is writing (the review gallery, or a generated demo project), a timeout or kill of the test process, or very large stdout from a scan.
- [ ] Fix the cause, with no retry wrapper and no skipped test.
- [ ] Ten full runs in a row without it.