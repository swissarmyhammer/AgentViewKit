---
assignees:
- claude-code
position_column: todo
position_ordinal: '80'
title: Decide if the sign-in card in the bottom bar of a thread gets the glass of the floating notes (D213 follow-up)
---
## What
After ^d213 work (card 01M84XDXE210R4P62QE0TQXFVX), the status notes of the top bar and the bottom bar of `AgentThreadView` are on the floating glass of the kit (`.statusBarPlacement(.floating)`). The sign-in card (`AgentLoginPrompt`, an `AgentAuthView`) also floats over the transcript in the bottom bar (`Sources/AgentViewKit/Connections/AgentLoginPrompt.swift`), but it is not a `StatusBar`, and D213 names only status notes. It still has no fill and no glass, so the transcript text can show through it, as it did through the notes.

- [ ] Ask the user if D213 also applies to the sign-in card.
- [ ] If yes: put the card on `.floatingGlass()` in the container of the bottom bar, and give its buttons the glass surface (bordered style), with a unit test first and a gallery screen.

#d213