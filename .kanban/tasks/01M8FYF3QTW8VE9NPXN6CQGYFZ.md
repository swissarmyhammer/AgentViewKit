---
assignees:
- claude-code
position_column: todo
position_ordinal: '8780'
title: The first scroll to the bottom of a thread ends at the bottom without a later layout pass
---
Found on 2026-11-27 in the work of ^6fax5yx (worktree virtual4, probes of the inspector gallery screen).

## Problem
In the inspector gallery screen, the bottom bar first gets a transient content inset of 1135.5 pt, the list unpins, and then it pins again. The first scroll to the bottom then goes to the last row (`ConversationLayout.scrollToLastRow`, `scrollTo(id:anchor:.bottom)`). That scroll first lands away from the bottom (log: visible rect minY -11, with content 703 pt and an inner height of 497.5 pt). The list ends at the bottom only when a later layout pass comes, in which SwiftUI applies the kept row id again (for example, when a row leaves the kept margin of the virtual stack). With no such pass, the image shows the list away from the bottom with the pill. ^6fax5yx removed the two causes of a missing pass, but the dependency stays.

## What
- [ ] Find why the first application of the row id lands away from the bottom (stale frame of the row, or the bottom inset).
- [ ] The first scroll ends at the bottom with no later pass.

## Tests
- [ ] RED first: a certain root unit test that reproduces the transient bottom inset and the first scroll.

#perf