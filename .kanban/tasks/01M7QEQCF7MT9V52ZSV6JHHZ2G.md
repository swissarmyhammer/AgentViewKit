---
assignees:
- claude-code
depends_on:
- 01M7QEQ262NCNK8H5K2NHBDXJ4
position_column: todo
position_ordinal: '8480'
title: Remove the transcript form of ThreadExporter and the thread-markdown template (D202)
---
Brief: /Users/wballard/github/swissarmyhammer/.briefs/export-markdown/avk-brief.md, proposed change 4. Do this after the Export as Markdown… verb replaces the Export button.

Do:
- Remove `ThreadExporter.markdown(for transcript:)` (Items/ThreadExporter.swift:31-33), the `thread-markdown` template (Resources/Templates/thread-markdown.stencil), and their tests (Tests/AgentViewKitTests/Text/TemplateTextTests.swift:21-44).
- Remove the `MarkdownDocument` and the "Thread" default name of the old Export button, if nothing else uses them.
- Keep the content form `markdown(for content:)` and the `message-markdown` template. Copy Message, the inspector and the item scope use them.
- Keep Copy Thread (`copy-text`) as it is.

Tests: the tests of Copy Message, Copy Thread and the inspector stay green. `swift test` is green. Push, and send the sha to testudoapp-9a.