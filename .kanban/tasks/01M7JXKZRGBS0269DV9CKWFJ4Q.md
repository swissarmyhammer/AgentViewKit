---
assignees:
- claude-code
position_column: done
position_ordinal: ffffffd880
title: 'AVK-10 (3/3): StatusLineView in the top bar of AgentThreadView'
---
D194, AVK-10. `StatusLineView` on the floating glass of the top bar in place of `AgentInfoHeader`, theme UI font and colors, no buttons. A click on a module calls the host action `.statusLineActions`; the header context menu path stays. Accessibility identifier `agent-status-line`, plain text label. A live model: FSEvents with a 0.5 s debounce and a refresh at the end of each turn. Bundled language icons. The host sets the definition (`.statusLine(_:)`). Gallery entries in and outside a repository, child session, full preset. Docs. #feature