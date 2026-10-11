---
assignees:
- claude-code
depends_on:
- 01M4P3B7BKPXEKTY742X7JCAT5
position_column: todo
position_ordinal: '8780'
title: 'Demo Gallery: the entry kinds and states that the recorded sessions do not have'
---
## What
The recorded SWE-bench sessions of the Gallery card have no user interaction. They do not show permission requests, form and URL elicitations, plans, compaction, notices of each severity, errors, attachments, the other stop reasons, or connection and sign-in states. To judge the look of these views, the Gallery needs sessions that have them.

Owner rules (2026-10-11): use a real session model; do not write a new replay agent that gets out of step with FoundationModelsACPAgent; no assertions on the content of fixture sessions.

## Work
- [ ] Find the best source for each missing kind: a recorded FoundationModelsACPAgent session that has it (preferred: record new sessions with FoundationModelsACPAgent that ask for permission, use a plan, compact, and so on, and copy them in as they are), or the existing `InMemoryDemoACPAgent` of `DemoSupport` where FoundationModelsACPAgent cannot produce the kind.
- [ ] Add these sessions to the Gallery next to the SWE-bench sessions.
- [ ] Record each kind that no source can produce, and why.