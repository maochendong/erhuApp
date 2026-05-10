import Foundation
import CoreData

@objc(PracticeRecordEntity)
public class PracticeRecordEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var date: Date
    @NSManaged public var scoreTitle: String
    @NSManaged public var accuracy: Double
    @NSManaged public var duration: Double
    @NSManaged public var totalNotes: Int32
    @NSManaged public var correctNotes: Int32
    @NSManaged public var noteDetails: Set<NoteDetailEntity>?
}

extension PracticeRecordEntity: Identifiable {
    @objc
    private class func keyPathsForValuesAffectingCorrectCount() -> Set<String> { Set(["correctNotes"]) }
}
