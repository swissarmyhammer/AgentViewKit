---
assignees:
- claude-code
position_column: todo
position_ordinal: '8180'
title: 'AVK-10 (2/3): status line data probes and module rendering'
---
D194, AVK-10. Probes off the main actor behind protocols: git with libgit2 in the process (swift-libgit2 exact 1.9.7; root, branch or detached hash, counts, stash, ahead/behind, state and progress), languages (repository index and untracked files that are not ignored, or a bounded walk). Pure rendering of each module (directory with `~`, repository root first, truncation, fish-style parents, substitutions; git_branch; git_status; git_state; languages; session; agent; model; context; time) to styled segments, with group and space rules. Unit tests with temp folders and repositories made with libgit2. #feature