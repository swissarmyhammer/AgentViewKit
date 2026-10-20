---
assignees:
- claude-code
position_column: done
position_ordinal: ffef80
title: AVK-2 Remove duplicate bindKey calls in AgentKeymap
---
Design: TestudoApp/features/packages/agentviewkit.md "AVK-2". EK-2 is done: `CommandRegistry.register` binds `CommandDefinition.keys`. `AgentKeymap.bind(into:at:)` repeats these keys with `bindKey` and clears the CUA layer with `resetKeymap`.

Do:
- Remove the `bindKey` calls that repeat `keys`, and the `resetKeymap` call.
- Bind only the chords that `keys` cannot hold (a second chord of a verb), with `source: verb.id`, so that a second `register` removes them.
- Update the tests that build the scope with `AgentKeymap.sortedChords`.

Acceptance: a second registration does not add a key again; the Esc of Stop resolves once; all tests pass.

TestudoApp task ^epv3h8h waits for this.