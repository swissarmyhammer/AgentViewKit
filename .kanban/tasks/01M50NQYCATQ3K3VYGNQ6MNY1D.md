---
assignees:
- claude-code
position_column: todo
position_ordinal: 8f80
title: 'ElicitationView: check the answer with validationFailure(of:) before send, show the failure, and send no value that the agent refuses'
---
Do not start this task during mail step 7 T4.

Background: FoundationModelsExtras task 19 adds `ElicitationRequestedSchema.validationFailure(of:) -> String?`. When an accepted form answer fails this check, the tool now gets a decline with the reason "the answer is not valid: …". Extras found places where ElicitationView can send content that now fails the check.

Work:
1. Before the send of an accepted answer, call `validationFailure(of:)` on the content. If it gives a failure, do not send. Keep the form open and show the failure text near the form (and announce it to VoiceOver).
2. Fix each source of content that fails the check:
   a. A required property of a kind that `normalize` drops: the key is missing from the content.
   b. An optional field that keeps a "" or [] default: it fails minLength, pattern, format, the select values or minItems. Do not send an empty optional value; leave the key out.
   c. When the user unchecks the last box of a multi-select, the view writes [] (ElicitationFieldViews.swift:771), and that fails minItems.
   d. The UI counts the length in Unicode scalars, but Extras counts it in Characters. Count it the same way as Extras.
   e. A field override that writes .null or a value of a wrong type.
3. Tests: one fixed-order test for each source (a to e) and for the check before the send (the form stays open and shows the failure). No .timeLimit, sleep, clock wait, poll or retry.

Needs FoundationModelsExtras with task 19 on main (branch main). Write all text in STE. #elicitation-phase-3