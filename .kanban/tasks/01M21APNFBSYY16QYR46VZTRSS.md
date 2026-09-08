---
depends_on:
- 01M21AHDHY0H7A92PP2KTRTZEZ
- 01M21AHYBMNR7CNDZRPMWRTRTY
- 01M21AK7DBCBMDHK82JY5RA063
- 01M21AHNHX7YF6D4268FQ3K3YA
- 01M21AH4QCEFEBPTZ8GR061H51
- 01M21ACHJYSF8G8R7HY3M70Z7F
- 01M21AMHZJF4YSR0ZFYVV6B45Q
- 01M21BCRF2JZ6W49NKXHE8KKT1
position_column: todo
position_ordinal: a580
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