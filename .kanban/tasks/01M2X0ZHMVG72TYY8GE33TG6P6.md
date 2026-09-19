---
assignees:
- claude-code
position_column: doing
position_ordinal: '80'
title: Make the thread actions required, and remove the LoggingThreadActions default
---
Today a host that gives no actions gets `LoggingThreadActions`: a send or a cancel only writes a log line, and nothing happens. This is a quiet failure. The user decided that a host must give the actions.

## Acceptance criteria
- [ ] `AgentThreadView` takes the actions in its initializer. A host cannot forget them.
- [ ] The environment default is no longer `LoggingThreadActions`. Keep `LoggingThreadActions` as a public type, because a host can still choose it.
- [ ] Each view that reads the actions from the environment gets them from the thread view, not from a silent default.
- [ ] Each preview, test and fixture in the package gives the actions. The test support helpers (for example `threadViewHarness`) keep their short form.
- [ ] `Docs/decisions/` records the change and the reason: a quiet failure is worse than a compile error.

## Tests
- [ ] All tests pass, and no test count goes down.
- [ ] A test shows that the actions of the initializer arrive at a child view (for example PromptInputView).

## Notes
This is a breaking change for the hosts that exist. Write the change in the commit message.