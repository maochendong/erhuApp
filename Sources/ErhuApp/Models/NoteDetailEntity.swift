import Foundation
import CoreData

@objc(NoteDetailEntity)
public class NoteDetailEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var noteIndex: Int32
    @NSManaged public var degree: Int32
    @NSManaged public var wasCorrect: Bool
    @NSManaged public var centsOff: Double
    @NSManaged public var timestamp: Double
    @NSManaged public var practiceRecord: PracticeRecordEntity?
}

extension NoteDetailEntity: Identifiable {}
