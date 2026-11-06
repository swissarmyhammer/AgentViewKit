import EditorInspector
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import Observation

/// A client model of FoundationModelsACPClient that an EditorKit
/// `InspectorView` shows through an ``InspectedClientModel``: the session
/// model and each transcript entry.
///
/// EditorKit's `InspectorScheme` makes the object part of the scheme id of
/// each row from the description of the `Identifiable` id of the inspected
/// object. The ids of these models, `TranscriptEntry.ID` and `SessionId`,
/// are types of FoundationModelsACP and FoundationModelsACPClient that have
/// no readable description: they would describe themselves as a debug
/// description, such as `SessionId(rawValue: "sess_1")`. So the kit shows
/// each model through an ``InspectedClientModel``, whose id is the text of
/// ``inspectorObjectID``.
public protocol InspectableClientModel: AnyObject, Observable {
  /// The object part of the scheme id of each row of the model, before
  /// EditorKit's `InspectorScheme` escapes each `%`, `/`, `.` and `+` in it
  /// as `%XX`.
  ///
  /// - A session is its raw session id: `sess_1`.
  /// - An entry from the wire is the id of its inspection, a `-`, and the
  ///   raw wire id of its item: `tool-call-call_1`, `user-message-msg_1`.
  ///   The kind keeps a thought and an agent message with one `messageId`
  ///   apart.
  /// - An entry from the wire with no wire id is `position-` and its
  ///   position in the transcript: `position-3`.
  /// - An entry that the client made is `local-` and its UUID:
  ///   `local-6F9619FF-8B86-D011-B42D-00C04FC964FF`.
  var inspectorObjectID: String { get }

  /// The groups and fields that the inspector shows for the model.
  static var inspection: Inspection<InspectedClientModel<Self>> { get }
}

/// A client model as an object of an EditorKit `InspectorView`, with the
/// readable id ``id``.
///
/// The object part of the scheme id of each row is the
/// ``InspectableClientModel/inspectorObjectID`` of the model, escaped by
/// EditorKit's `InspectorScheme`. For the tool call `call_1`, the title row
/// is `inspection:tool-call/object:tool-call-call_1/field:tool-call.title`.
/// For the session `sess_1`, the id row is
/// `inspection:session/object:sess_1/field:session.id`.
///
/// `InspectorView(model)` and `InspectorView(models)` wrap each model. A
/// selection of several types (`InspectorView([any Inspectable])`) holds
/// `InspectedClientModel(model)` for each model.
@Observable
public final class InspectedClientModel<Model: InspectableClientModel>: Inspectable, Identifiable {
  /// The inspected model.
  public let model: Model

  /// The readable id of the model, ``InspectableClientModel/inspectorObjectID``.
  public var id: String { model.inspectorObjectID }

  /// The service that opens the path of a chip of the model's path rows, or
  /// `nil` for the system default, a new ``AttachmentPresenter``.
  ///
  /// The inspection of a model is static, so its path rows cannot read the
  /// ``SwiftUI/EnvironmentValues/attachmentFileService`` of the view. A test
  /// gives a recording service here instead, so that no file opens.
  let fileService: (any AttachmentFileService)?

  /// The inspection of the model.
  public static var inspection: Inspection<InspectedClientModel<Model>> { Model.inspection }

  /// Makes the inspected object of a model, whose path chips open their
  /// file in its default application.
  ///
  /// - Parameter model: The model.
  public convenience init(_ model: Model) {
    self.init(model, fileService: nil)
  }

  /// Makes the inspected object of a model, whose path chips open their
  /// file with `fileService`.
  ///
  /// - Parameters:
  ///   - model: The model.
  ///   - fileService: The service that opens a path, or `nil` for the
  ///     system default.
  init(_ model: Model, fileService: (any AttachmentFileService)?) {
    self.model = model
    self.fileService = fileService
  }

  /// Opens the file or the folder at `url`, as the Open command of an
  /// attachment does: runs ``AgentAttachmentVerb/openAttachment`` on the
  /// attachment of `url` with ``fileService``, or with the system default.
  ///
  /// Each path row of the inspection runs it for a press on one of its
  /// chips (``InspectionPath``). A service that cannot open the path logs
  /// the failure.
  ///
  /// - Parameter url: The URL of the chip.
  func openPath(_ url: URL) {
    let service = fileService ?? AttachmentPresenter()
    _ = service.run(.openAttachment, on: Attachment(url: url))
  }
}

extension InspectableClientModel where Self: ObservableTranscriptEntry {
  /// The object id of the entry: the id of its inspection and its raw wire
  /// id, such as `tool-call-call_1`; `position-3` for an entry from the wire
  /// with no wire id; `local-` and the UUID for an entry that the client
  /// made.
  public var inspectorObjectID: String { id.inspectorObjectID }
}

extension TranscriptEntry.ID {
  /// The separator between the kind and the raw id of an object id, as in
  /// EditorKit's positional object id `task-1`.
  static let objectIDSeparator = "-"

  /// The kind of the object id of an entry that the client made.
  static let localKind = "local"

  /// The object id of the entry of this id, as
  /// ``InspectableClientModel/inspectorObjectID`` states it: its kind, a
  /// `-`, and its raw id.
  var inspectorObjectID: String {
    let (kind, rawID) = objectIDParts
    return [kind, rawID].joined(separator: Self.objectIDSeparator)
  }

  /// The kind and the raw id of the object id of the entry.
  private var objectIDParts: (kind: String, rawID: String) {
    switch self {
    case .wire(let id): id.objectIDParts
    case .local(let uuid): (Self.localKind, uuid.uuidString)
    }
  }
}

extension SessionEntry.ID {
  /// The kind of the object id of an entry from the wire with no wire id.
  static let positionKind = "position"

  /// The kind and the raw id of the object id of an entry from the wire:
  /// the id of the inspection of its kind and its raw wire id, or
  /// `position` and its position.
  fileprivate var objectIDParts: (kind: String, rawID: String) {
    switch self {
    case .userMessage(let id): (ClientInspectionID.userMessage, id.rawValue)
    case .agentMessage(let id): (ClientInspectionID.agentMessage, id.rawValue)
    case .agentThought(let id): (ClientInspectionID.thought, id.rawValue)
    case .toolCall(let id): (ClientInspectionID.toolCall, id.rawValue)
    case .terminal(let id): (ClientInspectionID.terminal, id.rawValue)
    case .plan(let id): (ClientInspectionID.plan, id.rawValue)
    case .compaction(let id): (ClientInspectionID.compaction, id.rawValue)
    case .sessionMessage(let id): (ClientInspectionID.sessionMessage, id.rawValue)
    case .unidentified(let position): (Self.positionKind, String(position))
    }
  }
}

extension InspectorView {
  /// Makes the view of one client model, or of nothing for `nil`, through
  /// its ``InspectedClientModel``.
  ///
  /// - Parameters:
  ///   - model: The model, or `nil` for an empty selection.
  ///   - id: The view id, or `nil` for the id of the inspection.
  public init<Model: InspectableClientModel>(_ model: Model?, id: String? = nil) {
    self.init(model.map(InspectedClientModel.init), id: id)
  }

  /// Makes the view of several client models of one type, folded into one
  /// form, through their ``InspectedClientModel``s.
  ///
  /// - Parameters:
  ///   - models: The models, in selection order.
  ///   - id: The view id, or `nil` for the id of the inspection.
  public init<Model: InspectableClientModel>(_ models: [Model], id: String? = nil) {
    self.init(models.map(InspectedClientModel.init), id: id)
  }
}
