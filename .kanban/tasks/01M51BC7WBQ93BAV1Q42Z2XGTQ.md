---
assignees:
- claude-code
depends_on:
- 01M51BBZPSYD6PQ2CSQAQQTHFK
position_column: todo
position_ordinal: '9480'
title: 'Elicitation task 34: make the request deck a separate public view (session and connection)'
---
elicitation-plan.md task 34, section 4. Do it as the accepted deck design (card 01M51BBZPSYD6PQ2CSQAQQTHFK) says. A public deck view for a SessionModel and for a ConnectionModel, on ACPClient pendingRequests / frontRequest / bringToFront. The prompt editor, the deck and the chat stream are three separate components; the app arranges them. Tests with the step 7 rules. Write all text in STE. #elicitation-phase-6