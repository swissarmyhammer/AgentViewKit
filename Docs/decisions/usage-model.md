# Usage model (R16)

status: accepted
date: 2026-09-16
plan: plan.md §3.2, §14 (R16)

## Question

Three sources give usage data. How does the kit merge them into one
`ContextUsage` value?

- FoundationModels `LanguageModelSession.Usage` (macOS 27). The session gives
  it as `LanguageModelSession.usage`. A stream gives it as
  `ResponseStream.Snapshot.usage`. A response gives it as
  `LanguageModelSession.Response.usage`.
- Private Cloud Compute `PrivateCloudComputeLanguageModel.QuotaUsage`
  (macOS 27). The model gives it as `quotaUsage`.
- ACP v2 `SessionUpdate.usage_update` (`UsageUpdate` with `Cost`).

## Sources read

- `FoundationModels.swiftmodule/arm64e-apple-macos.swiftinterface` in the
  macOS 27 SDK of Xcode.
  - `LanguageModelSession.Usage`: `input` (`totalTokenCount`,
    `cachedTokenCount`), `output` (`totalTokenCount`, `reasoningTokenCount`),
    `metadata`, and the computed `totalTokenCount`.
  - `SystemLanguageModel.contextSize` and
    `PrivateCloudComputeLanguageModel.contextSize`.
  - `SystemLanguageModel.tokenCount(for:)` for a collection of
    `Transcript.Entry`.
  - `PrivateCloudComputeLanguageModel.QuotaUsage`: `status`
    (`belowLimit(BelowLimit)` with `isApproachingLimit`, or
    `limitReached(LimitReached)`), `limitIncreaseSuggestion`, and `resetDate`.
- `FoundationModelsACP` generated models: `UsageUpdate` (`size`, `used`,
  `cost`, `_meta`) and `Cost` (`amount`, `currency`, `_meta`).

## Merge table

Each row maps one source field to one stored property of `ContextUsage`.
`ContextUsageTests` reads this table. The second cell of each row must be a
stored property name of `ContextUsage`, and each stored property must have a
row.

| source field | ContextUsage field | note |
| --- | --- | --- |
| ACP `UsageUpdate.used` | `used` | Tokens in the context window now. |
| ACP `UsageUpdate.size` | `size` | The size of the context window in tokens. |
| ACP `UsageUpdate.cost.amount` | `cost` | Goes to `Cost.amount`. The cost is cumulative for the session. |
| ACP `UsageUpdate.cost.currency` | `cost` | Goes to `Cost.currency`, an ISO 4217 code. |
| FM `tokenCount(for: session.transcript)` | `used` | The FoundationModels adapter counts the transcript entries, because `Usage` holds cumulative counts and not the context fill. |
| FM `SystemLanguageModel.contextSize` | `size` | For the on-device model. |
| FM `PrivateCloudComputeLanguageModel.contextSize` | `size` | For the Private Cloud Compute model. |
| FM `Usage.input.totalTokenCount` | `input` | Goes to `Input.total`. |
| FM `Usage.input.cachedTokenCount` | `input` | Goes to `Input.cached`. |
| FM `Usage.output.totalTokenCount` | `output` | Goes to `Output.total`. |
| FM `Usage.output.reasoningTokenCount` | `output` | Goes to `Output.reasoning`. |
| PCC `QuotaUsage.status` `belowLimit` | `quota` | Goes to `.belowLimit(approaching:)` with `BelowLimit.isApproachingLimit`. |
| PCC `QuotaUsage.status` `limitReached` | `quota` | Goes to `.limitReached`. |

## Fields that the kit does not merge

- FM `Usage.metadata` and ACP `_meta`: extension data with no fixed keys. A
  host that needs them reads the source directly.
- FM `Usage.totalTokenCount`: the sum of the input and output totals. A view
  can compute it from `input` and `output`.
- PCC `QuotaUsage.resetDate` and `limitIncreaseSuggestion`: the
  `LanguageModelError.rateLimited` and `QuotaLimitReached` errors also carry
  these values. The kit shows them on the error item (plan.md §9 A2), not in
  the usage view.

## Decision

- `ContextUsage` has two required fields, `used` and `size`, and four
  optional parts, `cost`, `input`, `output`, and `quota`.
- Each source fills only the parts that it has. An ACP thread has no `input`,
  `output`, or `quota`. A FoundationModels thread has no `cost`.
- A new value from a source replaces the parts that the source fills and
  keeps the other parts.
- `fraction` is `used / size`, clamped to `0...1`. It is `0` when `size` is
  `0`.
