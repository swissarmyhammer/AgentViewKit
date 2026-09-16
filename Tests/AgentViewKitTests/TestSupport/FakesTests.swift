import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import AuthenticationServices
import Foundation
import Synchronization
import Testing

/// Holds the results that a ``WebAuthSession`` completion gives.
nonisolated final class CompletionBox: Sendable {
  /// One call of the completion.
  struct Result: Sendable {
    /// The callback URL.
    let url: URL?
    /// The error.
    let error: (any Error)?
  }

  /// The results, in call order.
  private let storage = Mutex<[Result]>([])

  /// Records one call of the completion.
  ///
  /// - Parameters:
  ///   - url: The callback URL.
  ///   - error: The error.
  func record(_ url: URL?, _ error: (any Error)?) {
    storage.withLock { $0.append(Result(url: url, error: error)) }
  }

  /// The callback URL of each call, in order.
  var urls: [URL?] { storage.withLock { $0.map(\.url) } }

  /// The error of each call, in order.
  var errors: [(any Error)?] { storage.withLock { $0.map(\.error) } }
}

@Suite @MainActor struct FakesTests {
  // MARK: - Pasteboard

  @Test func fakePasteboardRecordsCopiesInOrder() {
    let pasteboard = FakePasteboard()
    let kitPasteboard: any AgentViewKit.Pasteboard = pasteboard

    kitPasteboard.copyText("first")
    kitPasteboard.copyText("second")

    #expect(pasteboard.copies == ["first", "second"])
    #expect(pasteboard.contents == "second")
    pasteboard.reset()
    #expect(pasteboard.copies.isEmpty)
    #expect(pasteboard.contents == nil)
  }

  @Test func systemPasteboardConformsAndWritesAString() {
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    let kitPasteboard: any AgentViewKit.Pasteboard = pasteboard

    kitPasteboard.copyText("copied")

    #expect(pasteboard.string(forType: .string) == "copied")
  }

  // MARK: - Announcer

  @Test func recordingAnnouncerRecordsAnnouncementsInOrder() {
    let announcer = RecordingAnnouncer()
    let kitAnnouncer: any Announcer = announcer

    kitAnnouncer.announce("Turn complete", priority: .medium)
    kitAnnouncer.announce("Action required", priority: .high)

    #expect(
      announcer.announcements == [
        .init(message: "Turn complete", priority: .medium),
        .init(message: "Action required", priority: .high),
      ])
    announcer.reset()
    #expect(announcer.announcements.isEmpty)
  }

  // MARK: - Focus

  @Test func recordingFocusReporterRecordsMovesInOrder() {
    let reporter = RecordingFocusReporter()
    let kitReporter: any FocusReporter = reporter

    kitReporter.focusMoved(to: "permission-card")
    kitReporter.focusMoved(to: "elicitation-form")

    #expect(reporter.moves == ["permission-card", "elicitation-form"])
    reporter.reset()
    #expect(reporter.moves.isEmpty)
  }

  // MARK: - Web authentication

  static let authorizationURL = URL(string: "https://auth.example.com/authorize")!
  static let callbackURL = URL(string: "agentviewkit://callback?code=1")!

  @Test func fakeWebAuthSessionCompletesWithTheScriptedURL() {
    let factory = FakeWebAuthSession(script: .callback(Self.callbackURL))
    let box = CompletionBox()
    let kitFactory: any WebAuthSessionFactory = factory

    let session = kitFactory.makeSession(url: Self.authorizationURL, callbackScheme: "agentviewkit") {
      url, error in
      box.record(url, error)
    }
    session.prefersEphemeralWebBrowserSession = true
    let started = session.start()

    #expect(started)
    #expect(box.urls == [Self.callbackURL])
    #expect(box.errors.count == 1)
    #expect(box.errors.first.flatMap { $0 } == nil)
    #expect(
      factory.calls == [
        .makeSession(url: Self.authorizationURL, callbackScheme: "agentviewkit"),
        .start(ephemeral: true),
      ])
    #expect(factory.sessions.count == 1)
  }

  @Test func fakeWebAuthSessionThrowsCancelled() throws {
    let factory = FakeWebAuthSession(script: .cancelled)
    let box = CompletionBox()

    let session = factory.makeSession(url: Self.authorizationURL, callbackScheme: "agentviewkit") {
      url, error in
      box.record(url, error)
    }
    #expect(session.start())

    #expect(box.urls == [nil])
    let error = try #require(box.errors.first.flatMap { $0 } as? ASWebAuthenticationSessionError)
    #expect(error.code == .canceledLogin)
    #expect(factory.calls.last == .start(ephemeral: false))
  }

  @Test func fakeWebAuthSessionCanFailToStart() {
    let factory = FakeWebAuthSession(script: .failsToStart)
    let box = CompletionBox()

    let session = factory.makeSession(url: Self.authorizationURL, callbackScheme: "agentviewkit") {
      url, error in
      box.record(url, error)
    }

    #expect(!session.start())
    #expect(box.urls.isEmpty)
  }

  @Test func fakeWebAuthSessionCancelCompletesOneTime() {
    let factory = FakeWebAuthSession(script: .failsToStart)
    let box = CompletionBox()

    let session = factory.makeSession(url: Self.authorizationURL, callbackScheme: "agentviewkit") {
      url, error in
      box.record(url, error)
    }
    session.cancel()
    session.cancel()

    #expect(box.errors.count == 1)
    #expect(
      factory.calls == [
        .makeSession(url: Self.authorizationURL, callbackScheme: "agentviewkit"),
        .cancel,
        .cancel,
      ])
    factory.reset()
    #expect(factory.calls.isEmpty)
    #expect(factory.sessions.isEmpty)
  }

  // MARK: - Process launcher

  @Test func fakeProcessLauncherRecordsTheLaunchAndFeedsOutput() async throws {
    let chunks = [Data("Open this URL\n".utf8), Data("Signed in\n".utf8)]
    let launcher = FakeProcessLauncher(scriptedOutput: chunks, scriptedExitStatus: 3)
    let kitLauncher: any ProcessLauncher = launcher

    let process = try kitLauncher.launch(
      program: "/usr/local/bin/agent",
      arguments: ["--login"],
      environment: ["AGENT_AUTH": "terminal"]
    )
    var received: [Data] = []
    for await chunk in process.output {
      received.append(chunk)
    }

    #expect(received == chunks)
    #expect(process.exitStatus == 3)
    #expect(
      launcher.calls == [
        .launch(program: "/usr/local/bin/agent", arguments: ["--login"], environment: ["AGENT_AUTH": "terminal"])
      ])
  }

  @Test func fakeProcessLauncherRecordsWritesAndTerminateInOrder() throws {
    let launcher = FakeProcessLauncher()

    let process = try launcher.launch(program: "/bin/agent", arguments: [], environment: [:])
    try process.write(Data("y\n".utf8))
    process.terminate()

    #expect(throws: FakeProcessLauncher.ProcessStoppedError()) {
      try process.write(Data("n\n".utf8))
    }
    #expect(
      launcher.calls == [
        .launch(program: "/bin/agent", arguments: [], environment: [:]),
        .write(Data("y\n".utf8)),
        .terminate,
        .write(Data("n\n".utf8)),
      ])
    let scripted = try #require(launcher.processes.first)
    #expect(scripted.writes == [Data("y\n".utf8)])
    #expect(scripted.isTerminated)
  }

  @Test func fakeProcessLauncherThrowsTheScriptedLaunchError() {
    let launcher = FakeProcessLauncher()
    launcher.launchError = .init(message: "not found")

    #expect(throws: FakeProcessLauncher.LaunchError(message: "not found")) {
      try launcher.launch(program: "/bin/missing", arguments: [], environment: [:])
    }
    #expect(launcher.calls == [.launch(program: "/bin/missing", arguments: [], environment: [:])])
    #expect(launcher.processes.isEmpty)
    launcher.reset()
    #expect(launcher.calls.isEmpty)
  }
}
