---
assignees:
- claude-code
position_column: todo
position_ordinal: a280
title: 'ElicitationURLConsentView: use elicitationHeaderOverride'
---
From the card 39 design, question Q7 (the step owner: not in card 39, a separate card for later). Write all text in STE.

## Fact
- `ElicitationView` uses `elicitationHeaderOverride` for its header. `ElicitationURLConsentView` uses `ElicitationHeader` directly (ElicitationURLConsentView.swift:164), so a header override of the app does not apply to URL cards.

## To do
- [ ] Decide with the step owner whether a URL card must use the same header override.
- [ ] If yes: use the override in ElicitationURLConsentView, with a hosted test, and update the doc comments.
- Rules: fixed order; no clock wait, sleep, poll, retry or timeLimit; event waits only. #elicitation-phase-6