# Thread accessibility

Status: decided. Source: plan.md §6, §14 research R11.
Task ^6vztrss. Date: 2026-09-17.

This file records how the thread views work with VoiceOver. The code is in
`Sources/AgentViewKit/Accessibility/ThreadAccessibility.swift` and
`Sources/AgentViewKit/Platform/Announcer.swift`. The hosted tests are in
`Tests/AgentViewKitTests/Accessibility/`.

## Linked reading groups

- `AgentThreadView` owns one namespace for the groups
  (`accessibilityReadingScope()`). `ConversationView` and `ResponseView` also
  apply the modifier. The modifier makes a namespace only when the
  environment has none, so a view outside a thread also has groups.
- Each paragraph element (`response-paragraph-N`) and the streaming tail
  element are in the group of their message. `MessageItemView` gives the
  message id to its subtree, so the paragraphs of all the text blocks of one
  message are in one group.
- Each row of the `LazyVStack` of `ConversationView` (`item-row-<id>`) is in
  the group `agent-thread`. The load-earlier row keeps its `causesPageTurn`
  trait and its scroll action. The list keeps its "N of M items" value.
- The harness reads the groups through `accessibilityLinkedUIElements()`, as
  `linkedElements`. The probe showed that SwiftUI links container elements
  on macOS 27, not only text elements. A lazy row that is not on screen has
  no element, so it has no link.

## Math in the reading order

Textual draws each math span in a canvas, so the text element of a paragraph
does not read the math. When a paragraph has math,
`MathMarkdownParser.spokenText(for:)` makes the plain text with the LaTeX
source of each span at its place. `MarkdownProse` combines the text into one
element with that text as its label. Thus VoiceOver reads each formula at
its place in the sentence.

The `math-inline` and `math-block` elements stay after the text, with their
identifiers and labels, so that a user can also move to each formula. A
paragraph with math is one element, so VoiceOver does not move to a link in
that paragraph.

## Announcements

The kit announces only at three boundaries. A streaming chunk gives no
announcement.

| Boundary | Text | Priority |
|----------|------|----------|
| A turn stops (running or requires action to idle) | "Response complete", "Response cancelled", or the `StateBanner` title of the stop reason | medium |
| A known tool call gets its result (completed, failed, cancelled, lost) | "<title>, <status>" (`ToolCallView.accessibilityLabel`) | medium |
| A new pending request | "Action required: <title>" | high |

- `ThreadAnnouncementObserver` is a hidden background of `AgentThreadView`.
  It reads the state, the tool call progress, and the pending requests. It
  does not read `AgentThread.streaming`.
- A tool call that the thread did not know before the change gives no
  announcement, so a thread that loads its history is silent.
- The environment value `announcer` is a `VoiceOverAnnouncer` by default.
  It posts `AccessibilityNotification.Announcement` with the
  `accessibilitySpeechAnnouncementPriority` attribute: low, default, or high.

## Focus

- `AccessibilityFocusMover` is the default focus reporter. It keeps the last
  move. Each view that can take the focus applies
  `accessibilityFocusTarget(_:)`, which sets an `@AccessibilityFocusState`
  when a move names its identifier.
- `AgentThreadView` gives a mover to its subtree
  (`accessibilityFocusScope()`). A host that shows the composer outside the
  thread view applies the same modifier to a view that holds both.
- The kit views tell the mover and the host `focusReporter` through one
  action (`AccessibilityFocusMove`). There is one `focusReporter`
  environment value.
- `PendingRequestsHost` moves the focus to the `pending-card-<id>` container
  of a new request, and to `prompt-editor` when no card stays.
  `PermissionView`, `ElicitationView`, and `ElicitationURLConsentView` also
  report their own identifier when they appear. Thus a reporter records the
  container and the card for a new permission request.
- `PromptInputView` puts the `prompt-editor` focus target on its editor slot,
  so the focus goes back to a custom editor too.

## Reduce Motion

- `ShimmerView` shows a static label when `accessibilityReduceMotion` is
  true. In a `DEBUG` build, its accessibility value is `animating` or
  `static`.
- `ToolCallView` removes its symbol effects when Reduce Motion is on.
- The kit has no glass morphing and no streaming text animation. A new view
  with motion must read `accessibilityReduceMotion` and expose its state in
  the same way as `ShimmerView`.

## Labels

- Tool call: "<title>, <status>".
- Reasoning block: "Reasoning, in progress", "Reasoning, N seconds", or
  "Reasoning" when the time is not known.
- Diff file row: "<language> diff, +A −R".

## Dynamic Type

See `dynamic-type.md`.
