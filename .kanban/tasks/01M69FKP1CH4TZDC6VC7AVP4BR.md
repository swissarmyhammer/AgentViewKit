---
assignees:
- claude-code
position_column: todo
position_ordinal: '8480'
title: 'CI red on main: FoundationModelsMultitool does not build against FoundationModelsExtras'' new SessionSendReceipt.Outcome.sent (blocked upstream)'
---
CI runs 41219735404 (5df5bb6) and 41223462155 (6ebd737) fail in Build & test and Examples with `switch must be exhaustive`, `add missing case: '.sent'`, at FoundationModelsMultitool SessionsGraphTypes.swift:333 and SessionsToolText+Messages.swift:123. AVK's own code did not cause it: CI resolves branch dependencies to latest main, and FoundationModelsExtras gained the case while Multitool's main has not caught up. Local `swift test` is green on 6ebd737 because the gitignored Package.resolved pins older revisions.

- [ ] Multitool handles `.sent` in both switches.
- [ ] Re-run CI on AVK main and confirm green.

#cross-repo