---
assignees:
- claude-code
position_column: done
position_ordinal: fff080
title: AVK-1 Agent command menu placement
---
Design: TestudoApp/features/packages/agentviewkit.md "AVK-1". EK-5 (CommandGroup placement, `SystemMenuSlot`) is done.

Do:
- Give each `agent.*` definition a `menu`, `contextMenu` and `icon`.
  - Session menu (`MenuPath("session")`): Send Message (⌘↩), Stop (⌘. and Esc), Focus Composer, Copy Thread (⇧⌘C).
  - View menu (`.view`): Next Prompt (⌥↓), Previous Prompt (⌥↑), Next Request (⇧⌘}), Previous Request (⇧⌘{), Expand or Collapse All, Scroll to Bottom.
  - Context menu of a message: Copy, Next Prompt, Previous Prompt.
  - Context menu of a request card: Approve Request, Reject Request.
- `AgentKeymap.defaultChords` holds a list of chords for each verb. Stop has ⌘. (first, shown in the menu) and Esc.
- Add the verb `copyMessage` ("Copy") that copies the Markdown of the clicked message.
- A message row has the scope `agentMessage:<rowKey>` and a request card has the scope `agentRequest:<uuid>`, both under `agentThread:<sessionId>`, with the EditorKit `commandContextMenu`.
- `isVisible` reads the invocation path, so that each context menu shows only its commands. Approve and Reject on a request card answer that request.

Acceptance: headless tests for the placements, the visibility at each path, the two Stop chords, Copy of one message, and Approve of the clicked request. All tests pass.

Depends on AVK-2. TestudoApp task ^epv3h8h waits for this.