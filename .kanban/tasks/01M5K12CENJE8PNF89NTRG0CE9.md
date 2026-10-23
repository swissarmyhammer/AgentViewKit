---
assignees:
- claude-code
position_column: todo
position_ordinal: a780
title: Tell the user why Submit of an elicitation form is disabled when an untouched default is not valid
---
## Problem

Since ^r8bnszx, `ElicitationView` shows the errors of a field only after the user changes the field, or after a call of `ElicitationFooterContext.submit` while the form is not complete. The default footer disables Submit while the form is not complete, so that call never comes from the default footer.

A field whose agent-given `default` breaks a constraint (for example `PreviewFixtures.invalidFieldElicitation`: `Retries` default 9 above its maximum) is not valid on the first render. The default form now shows no error for it, and Submit is disabled with no visible reason until the user happens to change that field. For a required empty field the required mark `*` explains the disabled Submit; for an invalid default nothing does.

## Change

Decide with the design how the form explains a disabled Submit when an untouched field is not valid. Options: show the errors of a non-empty answer at once (keep the delay only for the required message of an empty field), or let a press on the disabled Submit (or Return) count as a submit attempt.

## Tests

- A hosted test: a form whose default breaks a constraint tells the user why Submit is disabled, in the visible form and for VoiceOver. #avk-14