---
assignees:
- claude-code
position_column: todo
position_ordinal: af80
title: SessionStreamBanner gets a reload-failed phase and shows the stream error in its explanation, as KVK's stream banner does
---
From kanbanviewkit-2c's audit for ^qpbamj2: KVK's stream banner has a reload-failed phase and shows the stream error inside its explanation. AVK's SessionStreamBanner does neither. Both build on the shared StatusBar and StateBanner.Message (with severity) from AgentViewKitStyle, so the two kits should behave the same.

## Work
- [ ] After ^qpbamj2 lands, read KVK's banner logic (../KanbanViewKit, BoardStreamBanner) for the phases and wording
- [ ] SessionStreamBanner: when a reload fails, show a reload-failed message with `.failure` severity and the Reload action. Every failure message's explanation includes the stream error's localized description.
- [ ] Hosted tests for the reload-failed phase and for the error text in the explanation. Re-record any snapshot that changes.
- [ ] `swift test` is green

Order: after ^qpbamj2.