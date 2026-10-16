---
assignees:
- claude-code
depends_on:
- 01M51BBZPSYD6PQ2CSQAQQTHFK
- 01M51BCCSP0GHTT66H046ZHH46
position_column: todo
position_ordinal: '9780'
title: 'Elicitation task 37: do not move focus to new cards; announce them'
---
elicitation-plan.md task 37, section 4: a new card does not take the focus; a screen reader announces it; only the front card is available to VoiceOver. Do it as the accepted deck design says. Tests with the step 7 rules (RecordingAnnouncer is @Observable). Write all text in STE.

## Accepted design
Source: deck design section 4, part of section 8, test plan row 37 (design card 01M51BBZPSYD6PQ2CSQAQQTHFK).

Focus:
- A new card does not take the VoiceOver focus or the keyboard focus. Remove the focus-on-appear code at PermissionView.swift:179, ElicitationView.swift:154-156 and ElicitationURLConsentView.swift:154-156.
- The deck moves focus (AccessibilityFocusMove) only when:
  1. the old front left the deck: to pending-card-<new front>, or to prompt-editor when the deck is empty;
  2. the user changed the front (Previous, Next, a key, the tool call status): to the new front card, and the keyboard focus goes into it.
- A pure RequestDeck.focusTarget(oldIDs:newIDs:oldFront:newFront:) replaces PendingRequestsHost.focusTarget(old:new:).
- Only the front card is in the accessibility tree. Edge cards and hidden cards get accessibilityHidden(true). The header and "+N" are one element ("Request 1 of 6, 2 more").

Announcements:
- The deck announces each new request "Action required: <title>" at .high. This boundary moves from SessionAnnouncementObserver (ThreadAccessibility.swift:438-440) into the deck, so each deck announces its own model, and the connection deck announces the connection requests.
- Remove the pending-request part of SessionAnnouncementObserver.
- AgentThreadView keeps the end of a prompt's work and a tool result. ElicitationView keeps "answer not accepted" at .high. Still four boundaries.
- No announcement for Previous, Next, a withdrawn request or a URL waiting state.

Docs: Docs/decisions/accessibility.md focus and announcement sections; the doc comments of ElicitationCard and ElicitationURLConsentView.

Answers:
- Q2 yes: the deck announces each new request, so each request is announced one time.
- Q9 yes: keep .high for each new request.

Test plan (row 37). Rules: no clock wait, sleep, poll, retry or timeLimit. Hosted suites use .hostedSerially (HostedTestLock). After a main-actor change: render(). After async work: render(when:) or ObservationWait.until on a certain event. No new XCUITest, no new waitForExistence.
- [ ] focusTarget table test.
- [ ] A new request gives one "Action required: …" at .high, and RecordingFocusReporter records no move.
- [ ] An answer to the front of two requests moves the focus to the second card. An answer to the last one moves the focus to prompt-editor.
- [ ] Cards behind the front are not in the accessibility tree.
- [ ] The thread and the deck with two requests give exactly two announcements.
- Waits: render(when: announcer.announcements.count == 1) (RecordingAnnouncer is @Observable); ObservationWait.until { count == 1 }, then render().

#elicitation-phase-6