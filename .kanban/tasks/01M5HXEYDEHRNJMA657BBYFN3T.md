---
assignees:
- claude-code
position_column: todo
position_ordinal: a080
title: 'AVK-14b Add #Preview blocks for ElicitationCard, ElicitationWhoAsksLine and WithdrawnNoticeRow'
---
## Goal

The user examines the look of each component in the Xcode canvas. These request views have no `#Preview`:

- `Sources/AgentViewKit/Elicitation/ElicitationCard.swift` — `ElicitationCard`
- `Sources/AgentViewKit/Elicitation/ElicitationWhoAsks.swift` — `ElicitationWhoAsksLine`
- `Sources/AgentViewKit/HumanInTheLoop/RequestDeckWithdrawn.swift` — `WithdrawnNoticeRow`

## Change

Add `#Preview` blocks in the same file as each view. Use `Sources/AgentViewKit/Infrastructure/PreviewFixtures.swift`, and add to it if a value is missing. Give each preview a name that tells its state.

- [ ] `ElicitationCard`: a form with each field kind, a form with a field that is not valid, a URL consent request, and the card in content and in the request deck in the bottom bar.
- [ ] `ElicitationWhoAsksLine`: a short and a long name of the agent or the tool.
- [ ] `WithdrawnNoticeRow`: one withdrawn request, and a long title.

Also examine the `elicitation-form-*` snapshot: the message "This field is necessary." shows before the user types. Show that state in a preview, and record on this card whether it is correct.

## Rules

- No new public API. No backward compatibility code (ARCHITECTURE.md).
- The package builds with 0 warnings. The full suite passes with the window monitor. #avk-14