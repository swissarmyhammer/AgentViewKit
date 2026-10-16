---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m532fe71d2v1wsyn80snjfts
  text: 'Card 41 (^ergveft, 01M51BCMH8VHWE68GXDERGVEFT) fixes this defect, in the work tree (not committed). The RequestDeck now shows the accepted URL elicitation (awaitingURLCompletions) as a waiting card in the same ForEach, with the same id, so the card does not go away at the accept and onDisappear does not stop the browser. Hosted test: ElicitationURLConsentViewHostedTests.openInTheDeckKeepsTheBrowserSessionAndBringsTheNextCardToTheFront (no cancel on the fake presenter after the accept). aCompleteFromTheAgentRemovesTheWaitingCardAndStopsTheBrowser shows that the browser stops when the agent sends elicitation/complete. Before the fix, the first test failed at once: the waiting card was not in the deck after the render pass. This card stays in todo; the step owner moves it.'
  timestamp: 2026-10-16T19:19:30.785379+00:00
position_column: todo
position_ordinal: 9c80
title: 'ElicitationURLConsentView: the browser session stops when the user accepts a URL request'
---
Fact B of the accepted deck design (design card 01M51BBZPSYD6PQ2CSQAQQTHFK).

## Defect
When the user accepts a URL elicitation, the browser session that the card opened stops at once. The user cannot complete the flow in the browser.

## Chain (file:line)
1. ElicitationURLConsentView.open() (Sources/AgentViewKit/HumanInTheLoop/ElicitationURLConsentView.swift:223-228) accepts the request.
2. The accept removes the request from the model (acceptElicitation), so the card goes away.
3. The onDisappear of the card (ElicitationURLConsentView.swift:158-160) cancels the browser task.
4. AuthorizationPresenter.present (Sources/AgentViewKit/Connections/AuthorizationPresenter.swift:72) stops the browser on a cancel (:83-87, the cancellation handler calls cancel()).

## Repair
Do not repair this defect alone. It stays broken until task 41 (card 01M51BCMH8VHWE68GXDERGVEFT, "Elicitation task 41: show the URL elicitation waiting state"). Task 41 repairs it: after the accept, the model keeps the request in awaitingURLCompletions (ACPClient elicitation-plan task 52), and the deck keeps the same card mounted with the same id, so the card keeps its @State phase and its browser task.

## Check
- The task 41 test: press Open; the fake presenter is not cancelled; elicitation-waiting shows. The agent sends complete; the card goes away and the fake presenter records a cancel.
- Close this card when task 41 is done and that test passes.

Write all text in STE. #elicitation-phase-6 #bug