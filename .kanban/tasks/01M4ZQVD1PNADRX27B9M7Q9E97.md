---
assignees:
- claude-code
depends_on:
- 01M4ZQV6P05Y91E6AAAPVJE3W3
position_column: todo
position_ordinal: '8480'
title: 'Mail step 7 T4: Remove time limits and clock waits from the tests, align the docs, run the full suite, push, and report'
---
1. Remove the .timeLimit trait and each sleep, clock wait and poll in the tests. Use a wait on an event, a gate or a fixed order. A clock may only measure and print time.
2. Make the docs and comments agree with the new ACPAgent behavior (no turn words; state changes with no prompt open; an idle with no stop reason; more than one open prompt; cancel while idle with pending requests; the announcement only for the idle that ends a user prompt).
3. One full test run. Run the examples check if the CI runs it.
4. The final commit and the push. Report the head and the CI result.
5. Final report: the list of commits, and the check of mailbox.md row 7: "AgentViewKit builds and passes its tests against the mains that steps 1 to 6 checked, and elicitation-plan tasks 47 and 48 are done."

If a test hangs, take a `sample <pid>` of the test process first, then stop only that process id (never pkill or a pattern kill). Delete no test without a decision. Write all text in STE. #mail-step-7