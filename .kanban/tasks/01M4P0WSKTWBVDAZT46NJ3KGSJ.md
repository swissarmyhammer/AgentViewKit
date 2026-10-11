---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4p6bx084rn4vt413gc8mxdp
  text: |-
    Research:
    - The agent prose path is `ResponseView(id:markdown:)` (Content/ResponseView.swift). It splits paragraphs, renders each with Textual `StructuredText` through `MarkdownProse`, and applies `EditorKitCodeBlockStyle` and the `CodeBlockModelCache`. The empty state will use `ResponseView`, so it gets the same prose, math, link and code-block rendering.
    - `AgentInfoHeader` shows the pattern for a header: an SF Symbol from `SharedSymbol` in `editorTheme.accent` with `theme.symbolWeight`, hidden from VoiceOver, and a title with the `.isHeader` trait.
    - `ConversationView` reads `\.conversationPageSize` through an environment `@Entry` plus a public modifier. The host content for the empty state will use the same pattern (`.conversationEmptyState(...)`), and `ConversationEmptyState()` reads it. Thus `AgentThreadView` needs no change.
    - Existing hosted tests: `ConversationViewHostedTests` (empty-state tests), `ResponseViewHostedTests` (code block label "swift code block").
  timestamp: 2026-10-11T19:17:21.544554+00:00
- actor: claude-code
  id: 01m4p7ea31m9s383m6vtgczwa2
  text: |-
    Implementation landed (not committed):
    - New file `Sources/AgentViewKit/Thread/ConversationEmptyState.swift`: `ConversationEmptyState` with `init()` and `init(title:systemImage:markdown:)`, the internal `ConversationEmptyContent`, the internal environment value `conversationEmptyContent`, and the public modifier `.conversationEmptyState(title:systemImage:markdown:)`. The text renders through `ResponseView` (Textual + `EditorKitCodeBlockStyle`). The symbol uses `editorTheme.accent` and `theme.symbolWeight`. The title has the `.isHeader` trait and the identifier `ConversationLayout.emptyStateTitleIdentifier` (new). The default content ("No Messages", `SharedSymbol.conversation`, the old text) renders through the same path. An explicit init wins over the modifier. `AgentThreadView` needed no change: `ConversationEmptyState()` reads the environment.
    - `ConversationView.swift`: old struct removed, docs updated.
    - Tests: `Tests/AgentViewKitTests/Thread/ConversationEmptyStateHostedTests.swift` (7 tests). RED was a compile failure for the missing API; GREEN after the change.
    - Discovery: Textual gives a Markdown heading no heading trait. It is a plain AXStaticText. A link is an AXLink with the URL as its identifier and the link text as its label.
    - README: HostApp snippet uses the modifier, new section "The empty state"; snippets extracted. Demo: `ACPTabView` sets a welcome title and text. Demo app build: BUILD SUCCEEDED (UI tests not run).
    - comparison.md: table row, section 4.3 and section 5.3 updated.
    - Full `swift test`: 1068 tests in 116 suites passed (1 known issue that already existed), 104 tests in 10 suites passed, 1 README snippet test passed. Load average at start 161.91 / 129.02 / 118.36, at end 144.99 / 129.48 / 121.32.
  timestamp: 2026-10-11T19:36:09.057997+00:00
- actor: claude-code
  id: 01m4p7ecqhjgth5akashcz0m0b
  text: |-
    ### implement — changed
    - evidence: Sources/AgentViewKit/Thread/ConversationEmptyState.swift (new), Sources/AgentViewKit/Thread/ConversationView.swift, Tests/AgentViewKitTests/Thread/ConversationEmptyStateHostedTests.swift (new), README.md, Examples/ReadmeSnippets/Snippets/HostApp.swift, Examples/AgentViewKitDemo/AgentViewKitDemoFeature/ACPTabView.swift, comparison.md; swift test 1068 + 104 + 1 passed, 0 failed; load average 161.91 at start, 144.99 at end
    - next: /review
  timestamp: 2026-10-11T19:36:11.761693+00:00
depends_on:
- 01M4NQCJYNB9KF9RS503C1K7G8
position_column: doing
position_ordinal: '80'
title: 'ConversationEmptyState: show Markdown content that the host supplies'
---
## What
Decision of the owner (2026-10-11), from the review of `comparison.md` (section 4.3, row "Empty state / welcome"): the kit needs a `ConversationEmptyState` that shows Markdown content that the host supplies.

Today `ConversationEmptyState` (`Sources/AgentViewKit/Thread/ConversationView.swift:396-407`) is a static `ContentUnavailableView` with fixed text. `ConversationView` has an `emptyState` slot (`:149-164`, `:187-188`), and the default init uses `ConversationEmptyState()` (`:383-392`). Vercel AI Elements has `ConversationEmptyState`, assistant-ui shows a welcome view when the thread is empty, and CopilotKit has a `welcomeScreen` slot.

## Work
- [x] `ConversationEmptyState` takes Markdown content from the host (for example `init(markdown: String)`, and an init that also takes a title or a system image). It renders the Markdown with the same prose and code-block rendering as agent messages (Textual and `EditorKitCodeBlockStyle`), so links, lists and code blocks work and the EditorKit theme applies.
- [x] Keep a default with no host content (the current text), so `ConversationView(session:)` still shows an empty state.
- [x] Let the host set the content for the drop-in `AgentThreadView` too (an init parameter or an environment value / modifier such as `.conversationEmptyState(markdown:)`), without the custom `emptyState` slot.
- [x] Move `ConversationEmptyState` to its own file.
- [x] Accessibility: the content is readable by VoiceOver; keep `ConversationLayout.emptyStateIdentifier`.
- [x] Tests: hosted tests that the Markdown shows (heading, list, link, code block) when the transcript is empty and goes away after the first entry; the default still shows. README: show the use. Demo: give the empty state a short welcome text.
- [x] Update `comparison.md` section 4.3 and the table row when this is done.