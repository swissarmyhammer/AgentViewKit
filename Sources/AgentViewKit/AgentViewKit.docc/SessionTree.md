# Sub-agent sessions

Show a session and its child sessions, and move between them.

## Overview

A sub-agent is a child session. A root is a session with no parent. The model
is parent and child all the way down: a child can have children, and each rule here holds at each level. The
kit has no rule for a number of levels. The tree comes from
`FoundationModelsACPClient` (`SessionModel.parent`, `children`, `ancestors`,
`siblings`, `descendants`, `needsAttention`), and the views read it. The kit
keeps no copy.

Which session a window shows is state of the view, not of the model, so two
windows can show different sessions of one connection. ``AgentThreadView``
shows the session that you give it, which is the root of the tree. It shows the
root again after a resume.

### The path in the header

``AgentInfoHeader`` shows the agent, and then one crumb for each session from
the root to the shown session. Each crumb is a dropdown with the siblings at its
level, each with its state and its count of open questions. A crumb has a mark
when the session, or a session below it, needs the user. A last dropdown lists
the children of the shown session, with a limit and a count of the others.

When the path does not fit the width of the bar, the middle crumbs collapse into
one "..." dropdown. The agent keeps its place. This is a rule of the width of
the bar and not of the number of sessions in the path.

### Commands and jump

The session commands are in the View menu and in the palette: Go to Parent
Session, Open Child Session, Next and Previous Sibling Session, and Jump to
Session. The jump command opens a list of the ancestors and descendants of the
shown session, filtered by name, each with its path, such as
"Agent › Reviewer › Linter". Each crumb has its own focus scope, so the
keyboard moves between the crumbs.

### Banners

A banner tells when another session of the tree needs the user, and its button
jumps to it. A child that the client does not know yet, a child that failed to
restore (with the reason from the agent), and a child with no state each have
their own text. A child has no composer, because the client sends no prompt to
a child.

### The removal rule

A finished child is removed. ACP has no removal message: the client removes a
child when the tool call that started it has a final status. The `agents` tool
row jumps to the child while it exists. After the removal, the row stays as
history with a short "Finished" label. If you view a child that the client
removes, the view shows its parent.

### The break of the API

`AgentThreadView.init(session:connection:sessionTitle:headerContextMenuPath:composer:)`
lost the parameter `sessionTitle`, and so did `AgentInfoHeader`. The header
reads the session model, so it names the path itself. Remove the argument, and
give the root session.
