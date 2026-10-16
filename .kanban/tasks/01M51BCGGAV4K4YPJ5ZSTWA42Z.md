---
assignees:
- claude-code
depends_on:
- 01M51BBZPSYD6PQ2CSQAQQTHFK
- 01M51BCEHVNTKRD8YY4WZMKDF5
position_column: todo
position_ordinal: '9880'
title: 'Elicitation task 38: replace the inline elicitation form with a status that brings its card to the front'
---
elicitation-plan.md task 38, section 4: a tool call shows only "Waiting for your answer"; a click brings its card to the front (ACPClient bringToFront(toolCall:)); there is no second inline form in ToolCallView. Do it as the accepted deck design says. Tests with the step 7 rules. Write all text in STE. #elicitation-phase-6