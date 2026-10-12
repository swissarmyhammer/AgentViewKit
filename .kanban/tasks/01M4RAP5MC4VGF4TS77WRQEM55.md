---
assignees:
- claude-code
depends_on:
- 01M4RAHKJVTQFR205BQWV9BPNV
position_column: todo
position_ordinal: '80'
title: 'ACP tab: run FoundationModelsACPAgent in the process, not the sibling acp-agent program'
---
## What
Owner rule (2026-10-12): reference our packages and run them in the process; never start a binary from a sibling checkout. The ACP tab of the demo still starts `FoundationModelsACPAgent/.build/release/acp-agent` through `DemoLaunchOptions.defaultAgentCommand`, `--agent-command` and `DemoAgent.makeConnected(options:)`.

## Work
- [ ] Decide with the owner what the ACP tab must show by default: the in-memory demo agent (as the UI tests use today), or FoundationModelsACPAgent in the process (`ComposedAgent` with a model source). Record the decision.
- [ ] Remove the sibling-program path (`defaultAgentCommand`, `siblingAgentPath`, `agentArguments(for:)` and the `--agent-command` option if nothing else needs them), and the docs that describe it.
- [ ] If an external ACP agent program must stay possible (a real external agent such as another vendor), keep only a generic "external program" option that the user gives, with no sibling path.
- [ ] Tests and README.

This card depends on the in-process Gallery card (^wv9bpnv) because both change DemoAgent and DemoLaunchOptions.