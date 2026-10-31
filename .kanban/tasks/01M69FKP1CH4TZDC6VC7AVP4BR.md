---
assignees:
- claude-code
position_column: done
position_ordinal: ffffff8e80
title: 'CI red on main: FoundationModelsMultitool does not build against FoundationModelsExtras'' new SessionSendReceipt.Outcome.sent (blocked upstream)'
---
CI runs 41219735404 (5df5bb6) and 41223462155 (6ebd737) failed to compile: `switch must be exhaustive`, `add missing case: '.sent'`, in FoundationModelsMultitool. FoundationModelsExtras had gained the case first.

- [x] Multitool handles `.sent` in both switches (8b9bec2).
- [x] Re-run CI on AVK main: Build & test and Examples pass in run 41235913570. Integration fails for a separate reason, on its own card.

#cross-repo