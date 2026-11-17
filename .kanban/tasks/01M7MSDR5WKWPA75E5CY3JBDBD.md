---
assignees:
- claude-code
position_column: done
position_ordinal: ffffffdb80
title: 'Selectable message text: a right click shows the item menu, not the Textual menu'
---
From testudoapp-75 (TestudoApp UI run, AVK c2c73f8).

A right click on the text of a message shows the menu of Textual 0.5.0 (`NSTextInteractionView`: "Share…", "Copy"). It must show the item menu of AVK (`.commandContextMenu`: Copy Message, Inspect, Inspect in New Pane). Rule D193 (f).

Fix in Sources/AgentViewKit/Selection/TextualSelectionRegion.swift: one app-local event monitor for `.rightMouseDown` and control `.leftMouseDown`. When the hit view is an `NSTextInteractionView`, call `CommandContextMenuSiteView.prepareMenu(atWindowPoint:in:)`, take the first `menu(for:)` of the superviews, show it with `NSMenu.popUpContextMenu`, and discard the event. Command-C still copies the selection.

Tests: unit tests of the event filter and of the menu lookup; a hosted test in IntegrationTests. #bug