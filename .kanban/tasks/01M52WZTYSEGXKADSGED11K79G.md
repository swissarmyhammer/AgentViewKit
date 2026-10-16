---
assignees:
- claude-code
depends_on:
- 01M52QADYKA9KNNYBY174GYJM5
position_column: todo
position_ordinal: a080
title: 'Demo: give SessionListView the current session in ACPTabView'
---
Request of the step owner after card 40 (^b94apm2, commits ee57f08 and 4e86318). Write all text in STE.

## Fact
- Card 40 added `SessionListView(currentSession:)`. A row of an open session that is not the current session shows `PendingRequestCountBadge` and adds the count text to its label.
- The demo app (`Examples/.../ACPTabView.swift`) does not give `currentSession`. Thus the demo shows the badge on the row of the session that is on screen too.

## To do
- [ ] In ACPTabView, give `currentSession` the id of the session that the tab shows.
- [ ] Build the demo and run its tests one time (the Examples CI job builds AgentViewKitDemo). Use the commands of the demo target; follow the test rules: fixed order, no clock wait, sleep, poll, retry or timeLimit.
- [ ] Push with ^74gyjm5. #elicitation-phase-6