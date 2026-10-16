---
assignees:
- claude-code
position_column: todo
position_ordinal: a080
title: Hosted test nextMovesTheFocusAndTheKeyboardFocusIntoTheNewFrontCard waits without end when the focus move breaks
---
Found during the review of card 38 (^stwa42z, commit 768dfd0). Write all text in STE.

## Fact
- The review did one mutation check in `DeckCards.deckDidChange` (Sources/AgentViewKit/HumanInTheLoop/RequestDeck.swift): `keyboardFocus = id` became `_ = id`.
- The new test `nextMovesTheKeyboardFocusIntoAnElicitationCardSoEscapeCancelsOnlyIt` failed at once (0.331 s) at its `#require(model.pendingElicitations.isEmpty)`.
- The older test `nextMovesTheFocusAndTheKeyboardFocusIntoTheNewFrontCard` (Tests/AgentViewKitTests/HumanInTheLoop/RequestDeckAccessibilityHostedTests.swift, from card 37 ^wzmkdf5) has no `#require` before `await session.result(ofRequest:)`. With the mutation, the run did not stop in 30 minutes, and the reviewer killed it.
- Thus, when the keyboard focus move breaks, this test waits without end and does not fail. This is against the test rules: a wait must be on an event that is certain to happen.

## To do
- [ ] Before the `await session.result(ofRequest:)`, add a `#require` that the request was answered or cancelled after the key and one render(), as the new test does.
- [ ] Look for the same pattern in the other hosted tests that wait for `session.result(ofRequest:)` after a key press or an AX press, and correct each one.
- [ ] Prove the fix with one mutation run of each corrected test (put the source back after it), and one normal run.

#elicitation-phase-6 #bug