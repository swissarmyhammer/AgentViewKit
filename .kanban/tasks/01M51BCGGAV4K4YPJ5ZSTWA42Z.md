---
assignees:
- claude-code
depends_on:
- 01M51BBZPSYD6PQ2CSQAQQTHFK
- 01M51BCEHVNTKRD8YY4WZMKDF5
position_column: todo
position_ordinal: '9880'
title: 'Elicitation task 38: replace the inline elicitation form with a status that brings its card to the front'
---
elicitation-plan.md task 38, section 4: a tool call shows only "Waiting for your answer"; a click brings its card to the front (ACPClient bringToFront(toolCall:)); there is no second inline form in ToolCallView. Do it as the accepted deck design says. Tests with the step 7 rules. Write all text in STE.

## Accepted design
Source: deck design section 5, part of section 8, test plan row 38 (design card 01M51BBZPSYD6PQ2CSQAQQTHFK).

What to build:
- LinkedElicitations (ToolCallView.swift:317, :584) becomes ToolCallWaitingStatus: one button "Waiting for your answer" with a question symbol. It shows when entry.linkedElicitationIDs links a pending elicitation. No form in the row. Label "Waiting for your answer", hint "Shows the question".
- The press calls session.bringToFront(toolCall: entry). The deck then moves the focus (task 37).
- With no sessionModel in the environment, no status. If the app shows no deck, the press has no visible effect. The docs say so.
- Identifier tool-call-<id>-waiting replaces elicitationsIdentifier(for:).
- Task 39 (who asks) will go into the card headers (ElicitationHeader, the PermissionView header). It changes nothing in the deck.

What goes away:
- LinkedElicitations and ToolCallView.elicitationsIdentifier(for:) (ToolCallView.swift:246).

Inline forms in a tool call row today (read-only check of Sources/AgentViewKit/Items/ToolCallView.swift and Sources/AgentViewKit/Items/ToolCallPart.swift):
- Inline ELICITATION form: YES. ToolCallView.swift:317 mounts LinkedElicitations(entry:). LinkedElicitations (ToolCallView.swift:584-631) shows an ElicitationCard(request:owner:) for each linked pending elicitation (:600), in a container with elicitationsIdentifier(for:) (:603). The doc comment at ToolCallView.swift:76-79 says this. Remove it as above.
- Inline PERMISSION form: NO. Neither file has a PermissionView, an approve or reject control, or a read of pendingPermissions. Thus there is nothing more to remove for permissions.

Answers:
- Q8 yes: no tool call status for a pending permission now (bringToFront(toolCall:) links only elicitations). Rule: remove any inline permission form in a tool call row, if one exists today, so that the deck is the only place to answer. The check above found none. If one comes into these files before this task starts, remove it in this task.

Test plan (row 38). Rules: no clock wait, sleep, poll, retry or timeLimit. Hosted suites use .hostedSerially (HostedTestLock). After a main-actor change: render(). After async work: render(when:) or ObservationWait.until on a certain event. No new XCUITest, no new waitForExistence.
- [ ] A linked tool call shows tool-call-<id>-waiting and no form.
- [ ] Press: frontRequestID is the linked id, the header shows its position, and the last focus move is to its card.
- [ ] Answer: the status goes away.
- [ ] No tool call row shows an inline form for a permission or an elicitation.
- Waits: render(when: !pendingRequests.isEmpty) for the linked request; render() after the press; ObservationWait.until { pendingRequests.isEmpty } after the answer, then render().

#elicitation-phase-6