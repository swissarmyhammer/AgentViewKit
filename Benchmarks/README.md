# AgentViewKit benchmarks

This package measures the streaming paths of plan.md §8. It gives the numbers
for research R1 (the cost of Textual when a response streams). It records the
numbers as a committed baseline, and `Scripts/check-benchmarks.sh` fails when a
change makes a path slower than the baseline permits.

This is a **separate SwiftPM package** that depends on AgentViewKit by path, as
`../EditorKit/Benchmarks` is. The root package does not get the benchmark
dependencies, and `swift test` does not build the benchmarks.

## Run them

From the repository root:

```bash
# Each scenario, with a report.
swift package --package-path Benchmarks --disable-sandbox benchmark

# One scenario.
swift package --package-path Benchmarks --disable-sandbox benchmark \
    --filter "Streaming chunk, paragraph split on"

# The gate.
./Scripts/check-benchmarks.sh
```

The streaming scenarios mount SwiftUI views in an off-screen window. The
window server is not available in the sandbox of a package plugin, and a
SwiftUI render in the sandbox stops the process. Thus each command uses
`--disable-sandbox`.

The full suite takes about 50 seconds on the development machine (Apple
silicon, 32 cores, Darwin 27, Swift 6.4, release build).

## The scenarios

The package has no scenario now. The streaming scenarios of research R1
measured `StreamingMessage` and `StreamingCoalescer` of the old kit session
model. That model is removed (`Docs/decisions/acp-client-kit.md`): each view
of the kit reads the `TranscriptEntry` objects of `SessionModel`, and the
model coalesces the chunks (`SessionModel.defaultCoalescingCadence`). The
scenarios and their baselines went with the model. A later task adds an
observation benchmark of the transcript view over `SessionModel` and records
its baselines. Until then, `Scripts/check-benchmarks.sh` has no scenario to
check.

`BenchmarkHost.swift` and `BenchmarkPolicy.swift` stay for that benchmark.

The package has no observation benchmark of FoundationModels. The observation
benchmarks of research R4 measured a FoundationModels stream through
`SessionThreadSource`. The kit is an ACP client kit, so these benchmarks and
their baselines went with the FoundationModels adapter (update.md §7 item 2).

### The boundary

A package can use only the products of another package. To compile a file of
a test target or of the test support target, put a symbolic link to the file
in `Benchmarks/AgentViewKitBenchmarks/`, and edit the file in the root
package. `BenchmarkSymlinkTests` in `PackageStructureTests` fails when a link
points at a file that moved. The target has no link now.

`BenchmarkBoundaryTests` in `PackageStructureTests` fails when a benchmark
source imports FoundationModels or `AgentViewKitFoundationModels`, or when
`Package.swift` links the `AgentViewKitFoundationModels` product.

## The gates

Each scenario checks its own gates, and stops with an error when a gate
fails. `Scripts/check-benchmarks.sh` fails on such an error.

## R1: Textual streaming cost

This section is a record. The R1 scenarios and their baselines are removed
(see "The scenarios"), so the gate does not read these numbers. The
streaming tail, the lazy stack and `lazyResponseParagraphs` went with the old
session model. A `ResponseView` now shows the full text of an entry as
paragraphs, and each paragraph that does not change does not evaluate again
(`ParagraphReuseTests`).

### The numbers

The last baseline run:

| Scenario | p90 wall clock | p90 paragraphs parsed per chunk | p90 body evaluations per chunk |
| --- | --- | --- | --- |
| Split on | **3.30 ms** (the gate reads 3.18 ms) | 1 | 1 |
| Split off | **86.2 ms** | 449 | 1 |

With the split, one chunk costs the same at the start and at the end of the
message. With no split, the cost of one chunk grows with the message: at 500
paragraphs, one chunk parses 500 paragraphs and costs about 100 ms, which is
three coalescer intervals.

The first run of this benchmark failed the gate: the p90 was **46 ms** with the
split. Two costs grew with the message:

1. `StreamingMessage` split the full text again for each flush. At 500
   paragraphs the split took 1.2 ms. `ParagraphSplitter.split(_:resumingAt:)`
   now starts at the first line that is not settled, and the flush takes
   0.03 ms at each point of the message.
2. The settled paragraphs were in a `VStack`. Each chunk changes the height of
   the tail, and the stack placed each settled paragraph again: 0.1 ms for
   each paragraph. In a scroll view, the settled paragraphs are now in a
   `LazyVStack`, which places only the paragraphs on screen
   (`EnvironmentValues.lazyResponseParagraphs`, set by `ConversationView`).
   A lazy stack shows its content only in a scroll view, so a `ResponseView`
   outside a scroll view keeps the `VStack`.

After the two changes, the render of one chunk is 1.5 ms to 4 ms at each point
of the message. Most of it is the Textual parse and layout of the tail, and
the Core Animation commit of the frame.

### The decision

**The tail stays on Textual, with the paragraph split and the balancer. The kit
does not add a lighter tail renderer** (plan.md §11 decision 9). The split is
necessary: with no split, the cost of one chunk grows past the coalescer
interval. With the split, the resumed split, and the lazy stack, the p90 cost
of one chunk is 3.2 ms to 3.3 ms, under the 4 ms gate.

The gate has a margin of about 20 % on the development machine. The benchmark
window has a fixed size (`sizingOptions = []`), as the window of an app has.
If a slower machine fails the 4 ms gate, measure the tail render first: it is
the largest part of the cost.

## R4: observation granularity

This section is a record. The R4 scenarios and their baselines are removed
(see "The scenarios"), so the gate does not read these numbers. The decision
applies to `SessionThreadSource` while the FoundationModels adapter is in the
package.

### The numbers

The last baseline run, for one stream of 1,000 chunks:

| Tail source | p90 tail updates | p90 wall clock |
| --- | --- | --- |
| `Snapshot.transcriptEntries` | 970 | 14.2 ms |
| `SessionPropertyValues.history` | 692 | 15.6 ms |
| `session.transcript` | 690 | 15.6 ms |

| Observer, through `SessionThreadSource` | p90 invalidations per stream |
| --- | --- |
| `thread.items` | 3 (2 entries: the prompt and the response) |
| `thread.streaming[id]` | 3 |

- The stream gives one snapshot for almost each chunk. The two observed
  values change together: `session.properties.history` does not give a finer
  or a coarser granularity than `session.transcript`. An observer of either
  one gets fewer updates only because the changes between two main actor
  passes count as one.
- The first run of this benchmark found a leak: the items observer changed
  3 to 9 times for the same stream. Before the first snapshot opened the
  stream, the observation of `session.transcript` replaced the response item
  for each chunk. `SessionThreadSource` now keeps the response items of a turn
  while the turn streams, and replaces them one time at the end. The items
  observer now changes 3 times on each run.
- The streaming observer changes 3 times per stream, because
  `StreamingMessage` coalesces the chunks of one 33 ms interval.

### The decision

**`SessionThreadSource` takes the streaming tail from
`ResponseStream.Snapshot.transcriptEntries`**, as it does now:

- The snapshot source costs the least, and it gives each text in order, with
  the entry id of the response.
- `SessionPropertyValues.history` has the same granularity as
  `session.transcript`, and it gives no new data. The source does not use it.
- The source observes `session.transcript` only for entry boundaries: a new
  entry, a changed entry that does not stream, and a removed entry. A view
  reads `thread.items`, which changes only at entry boundaries, and the tail
  row reads `thread.streaming[id]`.

## The gate policy

`BenchmarkPolicy.swift` holds each number of the policy, which is the policy
of `../EditorKit/Benchmarks`:

- **Instructions**: the primary gate. Tolerance **25 %** at p50 and p90.
- **Wall clock**: the secondary gate. Tolerance **75 %** at p50 and p90.
- **Throughput**: recorded, not gated.
- **Large counts** (paragraphs parsed): tolerance **25 %**.
- **Small counts** (body evaluations): an absolute tolerance of **2**,
  because a change of one main actor pass moves a count of 3 by one.

## The baseline-update flow

The baseline is committed as two artifacts from the same run:

| Path | Purpose |
| --- | --- |
| `Benchmarks/Baselines/*.p90.json` | The baseline that a reader can review: the p90 of each metric of each scenario |
| `Benchmarks/.benchmarkBaselines/AgentViewKitBenchmarks/main/` | The baseline that `benchmark baseline check` reads |

Record both again, from the repository root:

```bash
swift package --package-path Benchmarks --disable-sandbox \
    --allow-writing-to-package-directory benchmark baseline update main

swift package --package-path Benchmarks --disable-sandbox \
    --allow-writing-to-package-directory \
    benchmark thresholds update main --path Benchmarks/Baselines
```

Then run `./Scripts/check-benchmarks.sh` and commit both paths in the same
change.

Record the baseline again for an intentional regression (and tell why in the
change), for an improvement past a threshold, for a new scenario, or for a
new recording machine. Do not record the baseline again to make a failed gate
pass.

## Adding a scenario

1. Put the scenario in the file for its area, or add a file with a
   `register…` function and call it from `Main.swift`.
2. Use `BenchmarkPolicy.configuration(iterations:countMetrics:)`. Do not
   write a threshold of your own.
3. Build the workload outside the measurement. Only the path under test goes
   between `startMeasurement()` and `stopMeasurement()`.
4. Record the baseline in the same change.
