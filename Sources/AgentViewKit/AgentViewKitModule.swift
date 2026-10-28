// The kit builds on the shared look of the view kits, and its public API
// names the types of that look: `StateBanner.message(for:)` gives a
// `StatusBar.Message`, a `DiffView` reads `\.diffLayout`. The kit re-exports
// the style library, so a host that imports AgentViewKit reads those types
// with no second import, and each file of the kit reads them too. The kit
// keeps no copy of the style (Package.swift, `AgentViewKitStyle`).
@_exported import AgentViewKitStyle

/// A marker for the `AgentViewKit` module, which holds the views that bind
/// to the client models of FoundationModelsACPClient, and the ACP helpers
/// in `ACP/`.
///
/// This placeholder gives the target one public symbol so that the package
/// builds. The model and view types replace it in later work.
public enum AgentViewKitModule {}
