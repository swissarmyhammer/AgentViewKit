---
assignees:
- claude-code
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