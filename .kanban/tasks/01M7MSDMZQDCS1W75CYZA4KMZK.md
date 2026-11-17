---
assignees:
- claude-code
position_column: done
position_ordinal: ffffffda80
title: 'Status line: the full width of the line opens the context menu'
---
From testudoapp-75 (TestudoApp UI run, AVK c2c73f8).

A right click on the empty part of the status line (center or trailing edge) shows no context menu. The click goes through the glass. A right click on the text shows the host path menu.

Fix: in `StatusLineContent.line(at:)`, add `.contentShape(Rectangle())` after `.frame(maxWidth: .infinity, alignment: .leading)`.

Tests: a hosted test in IntegrationTests/Thread/ThreadHeaderContextMenuHostedTests.swift reads the menu at the trailing part of the line. Rule D193 (f). #bug