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

The kit announces only at eight boundaries. A streaming chunk gives no
announcement.

| Boundary | Text | Priority |
|----------|------|----------|
| The first `idle` after the echo of a prompt of this client (by the `messageId` of the prompt response) | "Response complete", "Response cancelled", or the `StateBanner` title of the stop reason | medium |
| A known tool call gets its result (completed, failed, cancelled, lost) | "<title>, <status>" (`ToolCallView.accessibilityLabel`) | medium |
| A new pending request of the model of a `RequestDeck` | "Action required: <title>" | high |
| A new record in `withdrawnRequests` of the model of a `RequestDeck` (the agent withdrew a pending request with `$/cancel_request`) | "<title> was withdrawn: <reason>", or "<title> was withdrawn." with no reason | medium |
| The check before the send refuses an elicitation answer (`ElicitationView` does not send it) | "The agent cannot accept the answer for “<field title>”: <rule>", or "The agent cannot accept this answer: <rule>" when the issue has no field. The rule is the localized kit text of the issue kind, the same text as the field check for the same rule. | high |
| An elicitation form appears with a field whose default is not empty and not valid (`ElicitationView` shows the errors of that field at once, so the user learns why Submit is disabled) | "“<field title>”: <messages>" for each such field, in the order of the form | medium |
| A change of an elicitation answer makes the field show errors that it did not show before (`ElicitationView` shows the errors of another field only after the user changes it, or after a submit attempt) | "“<field title>”: <messages>" | medium |
| A submit attempt with an elicitation form that is not complete (`ElicitationFooterContext.submit` while `canSubmit` is `false`; the default footer disables Submit, so only a custom footer reaches it) | "“<field title>”: <messages>" for each field that is not valid, in the order of the form | high |

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
  It reads the stream of `makeTurnAnnouncements(of:)` and the status of each
  `ToolCallEntry` of the transcript. It keeps no copy of these values. Each
  tool result announcement compares only the old and the new value of one
  change of the model. It does not read the content of an entry, so a
  streamed chunk does not evaluate it.
- Each `RequestDeck` announces the new requests of its own model:
  `RequestDeck(session:)` the permission requests and the elicitations of
  the session, `RequestDeck(connection:)` the request-scoped elicitations of
  the connection. Thus each request is announced one time. The announcement
  compares only the old and the new requests of one change. Previous, Next,
  and a URL waiting state give no announcement.
- Each `RequestDeck` also announces each new record of a withdrawn request
  of its own model one time, with the text of the notice that the deck
  shows. The model removes the request from `pendingRequests` first, and the
  record comes in a later main-actor step. The announcement compares only
  the old and the new records of one change, so the Dismiss button of a
  notice gives no announcement. The notice takes no focus, and Dismiss moves
  no focus.
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
- `AgentThreadView` and `RequestDeck` give a mover to their subtrees
  (`accessibilityFocusScope()`) when the environment has none. The thread
  view shows no request card. The host puts the thread view, the
  `RequestDeck` and the composer in one view, and applies the same modifier
  to that view, so that the three use one mover.
- The kit views tell the mover and the host `focusReporter` through one
  action (`AccessibilityFocusMove`). There is one `focusReporter`
  environment value.
- `RequestDeck` shows one card for each pending request of its model, and
  one waiting card for each accepted URL elicitation in
  `awaitingURLCompletions`. It keeps no list of the requests: the models
  remove a request when it resolves.
- A new card does not take the VoiceOver focus or the keyboard focus.
  `PermissionView`, `ElicitationView`, and `ElicitationURLConsentView` do not
  move the focus when they appear. `ElicitationView` and
  `ElicitationURLConsentView` have no `defaultFocus`. `PermissionView` keeps
  its `defaultFocus`. The kit gives a new card no keyboard focus. AppKit
  decides the first keyboard focus of a window. Hosted tests show two
  results. In a window with only a URL consent card, which has no text
  field, a view of the card gets the keyboard focus and Esc cancels the
  request. A new card does not take the keyboard focus from a prompt editor
  that has it. No test shows the first keyboard focus for a card with a text
  field, or for a window with other focusable views. A manual check of the
  demo app records the first keyboard focus of the app window.
- The deck moves the focus only in two cases
  (`RequestDeck.focusTarget(oldIDs:newIDs:oldFront:newFront:)`):
  - The old front request left `pendingRequests`: the focus goes to the
    `pending-card-<id>` container of the new front request, or to
    `prompt-editor` when no pending request stays. The accept of a URL
    elicitation removes it from `pendingRequests`, and its card stays as a
    waiting card. A waiting card asks for no input and does not count, so
    the accept of the only pending request moves the focus to
    `prompt-editor` while the waiting card shows. The hosted test
    `anAcceptOfTheOnlyURLRequestMovesTheFocusToThePromptEditorAndKeepsTheWaitingCard`
    shows this.
  - The user changed the front (Previous, Next, a key, the tool call
    status): the focus goes to the card of the new front request, and the
    keyboard focus goes into that card. Hosted tests show this with Next for
    a permission card and for a URL consent card: after Next, Esc cancels
    only the request of the new front card.
- Only the front card and the waiting cards of accepted URL elicitations are
  in the accessibility tree. The edges and the cards that do not show are
  hidden from VoiceOver. "k of N" and "+N" are one element, for example
  "Request 1 of 6, 2 more". A waiting card is not in "k of N"; the header
  shows "N waiting".
- `PromptInputView` puts the `prompt-editor` focus target on its editor slot,
  so the focus goes back to a custom editor too.

## Reduce Motion

- `ShimmerView` shows a static label when `accessibilityReduceMotion` is
  true. In a `DEBUG` build, its accessibility value is `animating` or
  `static`.
- `ToolCallView` removes its symbol effects when Reduce Motion is on.
- The kit has no streaming text animation. The field glass and the editor
  menu glass of the composer have a `glassEffectID` (D113 answer 2), but the
  kit adds no animation to the show and the hide of a glass. Thus a glass
  morphs only in an animation that the host gives, and a host gives `nil` as
  the animation while Reduce Motion is on. A new view with motion must read
  `accessibilityReduceMotion` and expose its state in the same way as
  `ShimmerView`.

## Labels

- Tool call: "<title>, <status>".
- Tool call that waits for an elicitation: the button "Waiting for your
  answer", with the hint "Shows the question". The row shows no form.
- Tool call whose accepted URL elicitation waits for the end of the flow in
  the browser: the text "Waiting for <host>".
- URL elicitation card in the waiting state: "Waiting for <host> to finish",
  the button "Cancel", and the Retry button with the label "Open
  <agent> in the browser again".
- Reasoning block: "Reasoning, in progress", "Reasoning, N seconds", or
  "Reasoning" when the time is not known.
- Diff file row: "<language> diff, +A −R".

## Dynamic Type

See `dynamic-type.md`.
