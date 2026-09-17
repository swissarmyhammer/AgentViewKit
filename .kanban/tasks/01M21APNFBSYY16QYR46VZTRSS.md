---
comments:
- actor: claude-code
  id: 01m2nx9yy396kdjzpebyhas7mj
  text: 'Note from ^5a3wmgc (ElicitationView): the environment value `EnvironmentValues.focusReporter: (any FocusReporter)?` now exists in Sources/AgentViewKit/Platform/FocusReporter.swift. `ElicitationView` calls `focusMoved(to: "elicitation-form")` on appear. The focus-move work of this task must use this environment value and must not add a second one. PermissionView must call it with its own identifier on appear.'
  timestamp: 2026-09-16T20:07:37.155247+00:00
- actor: claude-code
  id: 01m2p0m0rvznj9yrjj2qj6vp1h
  text: 'Note from ^vznkzkp (MathView): Textual draws each inline math attachment in a `Canvas`, which has no accessibility children. `MarkdownProse` (Sources/AgentViewKit/Content/MarkdownProse.swift) adds `MathSpanAccessibility` in an overlay: one 1x1 element for each math span, with the identifier `math-inline` or `math-block` and the LaTeX source as the label. The paragraph text element does not read the math, and VoiceOver reads the math elements after the text. This task must put each math element at its place in the reading order of the paragraph (linked reading group), and must keep the identifiers and labels. See Docs/decisions/math-engine.md, section "Accessibility".'
  timestamp: 2026-09-16T21:05:32.443620+00:00
- actor: claude-code
  id: 01m2p3vd72g7vpx8yvrz8bayam
  text: 'Note from ^xa2n421 (ConversationView): the thread list is now `ConversationView` (Sources/AgentViewKit/Thread/ConversationView.swift). The linked reading group of the thread must wrap the rows of its `LazyVStack`. The "load-earlier-row" already has the `causesPageTurn` trait and an `accessibilityScrollAction` for the top edge. The `conversation-list` element has the value "N of M items". Keep these when you add the linked groups.'
  timestamp: 2026-09-16T22:02:00.290889+00:00
depends_on:
- 01M21AHDHY0H7A92PP2KTRTZEZ
- 01M21AHYBMNR7CNDZRPMWRTRTY
- 01M21AK7DBCBMDHK82JY5RA063
- 01M21AHNHX7YF6D4268FQ3K3YA
- 01M21AH4QCEFEBPTZ8GR061H51
- 01M21ACHJYSF8G8R7HY3M70Z7F
- 01M21AMHZJF4YSR0ZFYVV6B45Q
- 01M21BCRF2JZ6W49NKXHE8KKT1
position_column: doing
position_ordinal: '8180'
title: 'Accessibility: linked reading groups, VoiceOver boundary announcements, focus moves, Reduce Motion, Dynamic Type (plan §6, research R11)'
---
## What
Create `Sources/AgentViewKit/Accessibility/ThreadAccessibility.swift` and `Announcer.swift`, and apply them across the item views, per plan.md §6. This task settles research R11.

- `accessibilityLinkedGroup(id:in:)`: one group per message across its paragraph views, and one per thread across message rows, with a `@Namespace` owned by `AgentThreadView`. Verified through `accessibilityLinkedUIElements()` on the row elements, which the harness exposes as `linkedElements`.
- `Announcer` protocol with `announce(_ text: String, priority: AnnouncementPriority)`; the default posts `AccessibilityNotification.Announcement`. `EnvironmentValues.announcer`. The kit announces only at boundaries: turn complete, tool result, action required. Never per chunk. Priority high for action required.
- Focus: `PendingRequestsHost` calls the environment `FocusReporter` with the new card identifier and, on resolve, with `prompt-editor`. The default reporter sets `@AccessibilityFocusState`.
- Reduce Motion: `ShimmerView`, glass morphing, and streaming text animation read `\.accessibilityReduceMotion` and snap to the final state. Each exposes `isAnimating: Bool` under `#if DEBUG` through its accessibility value.
- Dynamic Type: every kit font uses a text style. Write a hosted probe that measures a `CodeBlockView` line height at `.large` and `.accessibility3` and record the result in `Docs/decisions/dynamic-type.md`; if EditorKit does not scale, the file names the EditorKit follow-up.
- Labels: tool calls "<title>, <status>"; reasoning "Reasoning, in progress" or "Reasoning, N seconds"; diffs "<language> diff, +A −R".

## Acceptance Criteria
- [ ] Each `response-paragraph-*` element in one message lists the other paragraphs of that message in `linkedElements`.
- [ ] Ten streaming chunks produce zero `RecordingAnnouncer` calls; a turn completion produces one; an action required produces one with high priority.
- [ ] `RecordingFocusReporter` records the permission card identifier on add and `prompt-editor` after the answer.
- [ ] With `\.accessibilityReduceMotion` true in the hosted environment, `ShimmerView` reports `isAnimating == false`.
- [ ] `Docs/decisions/dynamic-type.md` exists with the two measured line heights.

## Tests
- [ ] `Tests/AgentViewKitTests/Accessibility/ThreadAccessibilityHostedTests.swift`: groups, announcements, focus, reduce motion, through the injected fakes.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.