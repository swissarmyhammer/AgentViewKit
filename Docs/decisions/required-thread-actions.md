# The host must give the thread actions

Date: 2026-09-19

## Decision

`AgentThreadView` takes the `AgentThreadActions` in its initializer:

```swift
AgentThreadView(thread: thread, actions: source.actions)
```

The `threadActions` environment value is `(any AgentThreadActions)?`, and its
default is `nil`. There is no default object. `AgentThreadView` sets the value
for its subtree, so each card and each control of the thread calls the actions
of the host.

`LoggingThreadActions` stays a public type. A host selects it when it shows a
thread that no source drives, such as a transcript that it read from disk.
`AgentTranscriptView` uses it as the default of its `actions` parameter,
because a snapshot answers no request.

## Reason

Before this change the environment default was `LoggingThreadActions`. A host
that forgot the actions still compiled and still ran. The composer sent
nothing, the permission card answered nothing, and the only sign was one
`debug` line in the log. That is a quiet failure.

A quiet failure is worse than a compile error. A compile error names the file
and the line, and it stops before a user sees a dead button. Thus the kit takes
the actions where the host cannot forget them: in the initializer of the drop-in
view.

## Effects

- This is a breaking change. A host that calls `AgentThreadView(thread:)` must
  add the `actions:` argument.
- A view that reads `threadActions` from the environment reads an optional. A
  view that gets no actions does nothing, which is the same behavior as the
  logging actions, but no host reaches that state through the drop-in view.
- `AgentCommandTarget.actions` is optional for the same reason. A scope with no
  actions runs no send, no cancel, and no permission answer.

## Alternatives that the kit does not use

- **Actions that trap.** A default that calls `preconditionFailure` is loud,
  but it turns a host mistake into a crash for the user. The compile error
  comes first, so the trap adds risk and no value.
- **A default that logs.** That is the behavior that this decision removes.
