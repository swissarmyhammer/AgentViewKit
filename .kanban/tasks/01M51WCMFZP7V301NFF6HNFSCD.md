---
assignees:
- claude-code
position_column: todo
position_ordinal: 9d80
title: 'Later ACP message: tell the agent when the user stops waiting for a URL flow'
---
Q7 of the accepted deck design (design card 01M51BBZPSYD6PQ2CSQAQQTHFK).

## Status
NOT READY FOR WORK. This is not in v1. It needs a change to the ACP specification first. Do not start it until the step owner says so.

## Need
In v1, the "Stop waiting" button of a URL waiting card (task 41) calls stopWaiting(_:) in ACPClient and stops the browser. The agent gets no message. Thus the agent does not know that the user stopped the URL flow, and it can wait for an elicitation/complete that does not come.

A later ACP message must let the client tell the agent that the user stopped waiting for a URL elicitation (for example a notification with the elicitationId).

## Work (when ready)
- [ ] Propose the message to the ACP specification and get it accepted.
- [ ] ACPClient: send the message from stopWaiting(_:).
- [ ] ACPAgent: on the message, end the URL flow and clear its state.
- [ ] AgentViewKit: no view change is necessary, if Stop waiting still calls stopWaiting(_:). Update the docs that say "the agent gets no message".

Write all text in STE. #elicitation-phase-6