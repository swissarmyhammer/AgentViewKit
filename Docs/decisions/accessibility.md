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
  element are in the group of their message. `MessageLayout` gives the
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

The kit announces only at four boundaries. A streaming chunk gives no
announcement.

| Boundary | Text | Priority |
|----------|------|----------|
| The first `idle` after the echo of a prompt of this client (by the `messageId` of the prompt response) | "Response complete", "Response cancelled", or the `StateBanner` title of the stop reason | medium |
| A known tool call gets its result (completed, failed, cancelled, lost) | "<title>, <status>" (`ToolCallView.accessibilityLabel`) | medium |
| A new pending request of the models | "Action required: <title>" | high |
| The check before the send refuses an elicitation answer (`ElicitationView` does not send it) | "The agent cannot accept this answer: <reason>" | high |

- A prompt is mail (ACPAgent 293be4b). The order on the wire is: the
  prompt response with the `messageId`, the `user_message` echo with that
  `messageId`, `running`, the work, and then `idle`. The first `idle` after
  the echo ends the work of the prompt. Thus a change to `idle` alone does
  not announce:
  - An `idle` after background work only (no echo of a prompt of this
    client after the last announcement) announces nothing.
  - A later `idle` with no new prompt announces nothing.
  - One `idle` that ends the work of two open prompts announces one time.
  - The echo of a user message that this client did not send announces
    nothing.
- `ThreadAccessibility.makeTurnAnnouncements(of:)` finds these idles. It
  reads `SessionModel.updateTap()` in arrival order, because the model state
  does not tell when the echo arrived. It matches the echo to a prompt of
  this client only by the `messageId`: the `messageId` of each local user
  message of the transcript. The schema requires the `messageId` on the
  prompt response and on the echo. An agent that sends no echo for a prompt
  gives no "Response complete" for that prompt.
- `SessionAnnouncementObserver` is a hidden background of `AgentThreadView`.
  It reads the stream of `makeTurnAnnouncements(of:)`, the status of each
  `ToolCallEntry` of the transcript, and the pending requests of
  `SessionModel` and of `ConnectionModel` (`pendingPermissions` and
  `pendingElicitations`). It keeps no copy of these values. Each tool result
  and action required announcement compares only the old and the new value
  of one change of the model. It does not read the content of an entry, so
  a streamed chunk does not evaluate it.
- A tool call that the session model did not have before the change gives
  no announcement. While `SessionModel.isReplaying` is true, the replay of a
  resume gives no stop announcement and no tool result announcement. Thus a
  session that loads its history is silent.
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
- `PendingRequestsHost` shows one card for each pending request of the
  models. It moves the focus to the `pending-card-<id>` container of a new
  request, and to `prompt-editor` when no card stays. It keeps no list of
  the requests: the models remove a request when it resolves.
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
