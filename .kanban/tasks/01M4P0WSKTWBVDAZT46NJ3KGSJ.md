---
assignees:
- claude-code
depends_on:
- 01M4NQCJYNB9KF9RS503C1K7G8
position_column: todo
position_ordinal: '8480'
title: 'ConversationEmptyState: show Markdown content that the host supplies'
---
## What
Decision of the owner (2026-10-11), from the review of `comparison.md` (section 4.3, row "Empty state / welcome"): the kit needs a `ConversationEmptyState` that shows Markdown content that the host supplies.

Today `ConversationEmptyState` (`Sources/AgentViewKit/Thread/ConversationView.swift:396-407`) is a static `ContentUnavailableView` with fixed text. `ConversationView` has an `emptyState` slot (`:149-164`, `:187-188`), and the default init uses `ConversationEmptyState()` (`:383-392`). Vercel AI Elements has `ConversationEmptyState`, assistant-ui shows a welcome view when the thread is empty, and CopilotKit has a `welcomeScreen` slot.

## Work
- [ ] `ConversationEmptyState` takes Markdown content from the host (for example `init(markdown: String)`, and an init that also takes a title or a system image). It renders the Markdown with the same prose and code-block rendering as agent messages (Textual and `EditorKitCodeBlockStyle`), so links, lists and code blocks work and the EditorKit theme applies.
- [ ] Keep a default with no host content (the current text), so `ConversationView(session:)` still shows an empty state.
- [ ] Let the host set the content for the drop-in `AgentThreadView` too (an init parameter or an environment value / modifier such as `.conversationEmptyState(markdown:)`), without the custom `emptyState` slot.
- [ ] Move `ConversationEmptyState` to its own file.
- [ ] Accessibility: the content is readable by VoiceOver; keep `ConversationLayout.emptyStateIdentifier`.
- [ ] Tests: hosted tests that the Markdown shows (heading, list, link, code block) when the transcript is empty and goes away after the first entry; the default still shows. README: show the use. Demo: give the empty state a short welcome text.
- [ ] Update `comparison.md` section 4.3 and the table row when this is done.