---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m537aj704w8wqm6xmm31x6jy
  text: |-
    ### Extras rules (from the step owner; Extras is pushed, its CI run 38964017964 was running)
    Source of truth: FoundationModelsExtras Sources/FoundationModelsExtras/OperationEvents/ElicitationValidation.swift — the doc of ElicitationRequestedSchema.validationFailure(of:) and the private enum ECMAPattern.
    Rules:
    - minLength and maxLength count Unicode code points (String.unicodeScalars): "e\u{301}" has length 2, "👍" has length 1.
    - pattern is ECMA-262, with no flags, and it is NOT anchored (a search; a whole-value match needs ^ and $). A pattern that does not compile fails the field.
    - Translation onto NSRegularExpression: \d = [0-9]; \w = [A-Za-z0-9_]; \b and \B use that \w; \s adds U+000B and U+FEFF; \v = U+000B; "." = any code point except \n, \r, U+2028 and U+2029; $ = end of the value only (\z); [] matches nothing; [^] matches each code point; in a class, "[" and "&" are literal, and [\b] is U+0008.
    - NaN and plus or minus infinity fail each number field.
    Recommendation of the step owner: one source of truth. AgentViewKit already gets FoundationModelsExtras through ACPAgent and ACPClient. If the form schema of the kit maps cleanly to ElicitationRequestedSchema, call validationFailure(of:) and delete the own check of the kit. If the map is not clean, tell the step owner why before you copy the translation.
    Tests: use the same examples as Extras — an Arabic-Indic digit against \d; "zip 12345" against "[0-9]{5}"; "e\u{301}" with maxLength 1.
  timestamp: 2026-10-16T20:44:13.920295+00:00
depends_on:
- 01M51BCMH8VHWE68GXDERGVEFT
position_column: todo
position_ordinal: a080
title: 'Decision D-1: answer checks follow JSON Schema (pattern not anchored, lengths in code points)'
---
Decision D-1 of the step owner (elicitation-plan.md section 10). Write all text in STE.

## Decision
- The answer checks of an elicitation form follow JSON Schema.
- `pattern` is an ECMA-262 regular expression, and it is NOT anchored: the check is a search, not a full match.
- `minLength` and `maxLength` count Unicode code points, not Swift `Character` values.

## Order
- FoundationModelsExtras changes its validation first. The step owner sends the exact Extras rules when Extras is done.
- Do not change AgentViewKit for D-1 before that message. Do this card after card 41 (^ergveft).

## To do (after the Extras rules come)
- [ ] Read the Extras rules from the step owner and record them on this card.
- [ ] Find each answer check in AgentViewKit (for example ElicitationValidator) and make it agree with the Extras rules.
- [ ] Tests: a pattern that matches only a part of the text passes; a text with characters made of more than one code point (for example an emoji with a skin tone, or a letter with a combining mark) is counted in code points for minLength and maxLength. Fixed order; no clock wait, sleep, poll, retry or timeLimit.
- [ ] Docs and doc comments say only what the code does. #elicitation-phase-6