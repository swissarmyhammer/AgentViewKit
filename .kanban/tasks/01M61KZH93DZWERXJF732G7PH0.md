---
assignees:
- claude-code
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