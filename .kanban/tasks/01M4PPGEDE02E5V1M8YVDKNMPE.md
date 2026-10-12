---
assignees:
- claude-code
position_column: todo
position_ordinal: 8a80
title: 'SF Symbols: add icons to the text-only buttons of the permission comment row and the elicitation cards'
---
## What
Card ^02jyret added icons to the text-only action buttons that the audit named. Some text-only buttons are not on that card. Use `Label(_:systemImage:)` and read each symbol from `SharedSymbol`. Paths are below `Sources/AgentViewKit/`.

## Work
- [ ] `HumanInTheLoop/PermissionView.swift`: the "Send" button of the comment row (`SharedSymbol.send` can apply) and the "Allow and Switch to Auto Mode" button.
- [ ] `Elicitation/ElicitationView.swift`: the "Cancel", "Decline" and "Submit" buttons.
- [ ] `Elicitation/ElicitationURLConsentView.swift`: the "Cancel", "Decline", "Open in Browser" and "Retry" buttons.
- [ ] Add each new concept to `SharedSymbol`. Two concepts must not share a symbol. Add the uses to `SymbolConceptTests`.
- [ ] Hosted tests that find each button and its label.