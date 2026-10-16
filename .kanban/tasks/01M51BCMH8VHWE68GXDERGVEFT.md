---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m51bdracz0he6gmjr5prx2gj
  text: |-
    ### Prerequisite done (from the step owner)
    Elicitation task 8 is done in ACPAgent 3a3d67e: after a URL accept, the agent sends elicitation/complete only when the flow ends, or when the question ends with no answer. Thus the "waiting" state in the client can last, and this task can show it.
  timestamp: 2026-10-16T03:17:23.916001+00:00
depends_on:
- 01M51BBZPSYD6PQ2CSQAQQTHFK
- 01M51BCJD70S015GWDGB94APM2
position_column: todo
position_ordinal: 9a80
title: 'Elicitation task 41: show the URL elicitation waiting state'
---
elicitation-plan.md task 41: show the waiting state of a URL elicitation after the user gave consent and until the flow ends. Needs ACPAgent task 8 (send URL elicitation complete only when the flow ends); check its state before the work. Do it as the accepted deck design says. Tests with the step 7 rules. Write all text in STE. #elicitation-phase-6