import CoreData

/// Core Data stack for persisting practice records and user data.
final class PersistenceController: @unchecked Sendable {
    static let shared = PersistenceController()

    let persistentStoreCoordinator: NSPersistentStoreCoordinator
    let viewContext: NSManagedObjectContext

    private init() {
        let model = Self.buildModel()
        persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)

        let storeURL = Self.storeURL()
        try? persistentStoreCoordinator.addPersistentStore(
            type: .sqlite,
            at: storeURL,
            options: [
                NSMigratePersistentStoresAutomaticallyOption: true,
                NSInferMappingModelAutomaticallyOption: true
            ]
        )

        let concurrencyType = NSManagedObjectContext.ConcurrencyType.mainQueue
        viewContext = NSManagedObjectContext(concurrencyType)
        viewContext.persistentStoreCoordinator = persistentStoreCoordinator
        viewContext.automaticallyMergesChangesFromParent = true
    }

    private static func storeURL() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("ErhuApp.sqlite")
    }

    func save() {
        guard viewContext.hasChanges else { return }
        do {
            try viewContext.save()
        } catch {
            print("Core Data save error: \(error)")
        }
    }

    // MARK: - Practice Records

    func savePracticeResult(scoreTitle: String, accuracy: Double, duration: TimeInterval,
                            totalNotes: Int, correctNotes: Int, judgments: [PitchJudger.Judgment]) -> NSManagedObjectID? {
        let record = PracticeRecordEntity(context: viewContext)
        record.id = UUID()
        record.date = Date()
        record.scoreTitle = scoreTitle
        record.accuracy = accuracy
        record.duration = duration
        record.totalNotes = Int32(totalNotes)
        record.correctNotes = Int32(correctNotes)

        for (index, j) in judgments.enumerated() {
            let detail = NoteDetailEntity(context: viewContext)
            detail.id = UUID()
            detail.noteIndex = Int32(index)
            detail.degree = Int32(j.note.degree)
            detail.wasCorrect = j.isCorrect
            detail.centsOff = j.centsOff
            detail.timestamp = j.timestamp
            detail.practiceRecord = record
        }

        save()
        return record.objectID
    }

    func fetchPracticeRecords() -> [PracticeRecordEntity] {
        let request: NSFetchRequest<PracticeRecordEntity> = PracticeRecordEntity.fetchRequest() as! NSFetchRequest<PracticeRecordEntity>
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PracticeRecordEntity.date, ascending: false)]
        return (try? viewContext.fetch(request)) ?? []
    }

    func fetchPracticeRecords(forScore title: String) -> [PracticeRecordEntity] {
        let request: NSFetchRequest<PracticeRecordEntity> = PracticeRecordEntity.fetchRequest() as! NSFetchRequest<PracticeRecordEntity>
        request.predicate = NSPredicate(format: "scoreTitle == %@", title)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PracticeRecordEntity.date, ascending: true)]
        return (try? viewContext.fetch(request)) ?? []
    }

    func deletePracticeRecord(_ record: PracticeRecordEntity) {
        viewContext.delete(record)
        save()
    }

    // MARK: - Programmatic Core Data Model

    private static func buildModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // PracticeRecord entity
        let recordEntity = NSEntityDescription()
        recordEntity.name = "PracticeRecordEntity"
        recordEntity.managedObjectClassName = "PracticeRecordEntity"

        let recordId = NSAttributeDescription()
        recordId.name = "id"
        recordId.type = .uuid
        recordId.isOptional = false

        let recordDate = NSAttributeDescription()
        recordDate.name = "date"
        recordDate.type = .date
        recordDate.isOptional = false

        let recordScoreTitle = NSAttributeDescription()
        recordScoreTitle.name = "scoreTitle"
        recordScoreTitle.type = .string
        recordScoreTitle.isOptional = false

        let recordAccuracy = NSAttributeDescription()
        recordAccuracy.name = "accuracy"
        recordAccuracy.type = .double
        recordAccuracy.isOptional = false

        let recordDuration = NSAttributeDescription()
        recordDuration.name = "duration"
        recordDuration.type = .double
        recordDuration.isOptional = false

        let recordTotalNotes = NSAttributeDescription()
        recordTotalNotes.name = "totalNotes"
        recordTotalNotes.type = .integer32
        recordTotalNotes.isOptional = false

        let recordCorrectNotes = NSAttributeDescription()
        recordCorrectNotes.name = "correctNotes"
        recordCorrectNotes.type = .integer32
        recordCorrectNotes.isOptional = false

        recordEntity.properties = [recordId, recordDate, recordScoreTitle, recordAccuracy,
                                   recordDuration, recordTotalNotes, recordCorrectNotes]

        // NoteDetail entity
        let detailEntity = NSEntityDescription()
        detailEntity.name = "NoteDetailEntity"
        detailEntity.managedObjectClassName = "NoteDetailEntity"

        let detailId = NSAttributeDescription()
        detailId.name = "id"
        detailId.type = .uuid
        detailId.isOptional = false

        let detailNoteIndex = NSAttributeDescription()
        detailNoteIndex.name = "noteIndex"
        detailNoteIndex.type = .integer32
        detailNoteIndex.isOptional = false

        let detailDegree = NSAttributeDescription()
        detailDegree.name = "degree"
        detailDegree.type = .integer32
        detailDegree.isOptional = false

        let detailWasCorrect = NSAttributeDescription()
        detailWasCorrect.name = "wasCorrect"
        detailWasCorrect.type = .boolean
        detailWasCorrect.isOptional = false

        let detailCentsOff = NSAttributeDescription()
        detailCentsOff.name = "centsOff"
        detailCentsOff.type = .double
        detailCentsOff.isOptional = false

        let detailTimestamp = NSAttributeDescription()
        detailTimestamp.name = "timestamp"
        detailTimestamp.type = .double
        detailTimestamp.isOptional = false

        detailEntity.properties = [detailId, detailNoteIndex, detailDegree,
                                   detailWasCorrect, detailCentsOff, detailTimestamp]

        // Relationship: PracticeRecord → NoteDetail (one-to-many)
        let detailsRelation = NSRelationshipDescription()
        detailsRelation.name = "noteDetails"
        detailsRelation.destinationEntity = detailEntity
        detailsRelation.minCount = 0
        detailsRelation.maxCount = 0
        detailsRelation.deleteRule = .cascadeDeleteRule
        detailsRelation.isOptional = true

        let recordRelation = NSRelationshipDescription()
        recordRelation.name = "practiceRecord"
        recordRelation.destinationEntity = recordEntity
        recordRelation.minCount = 1
        recordRelation.maxCount = 1
        recordRelation.deleteRule = .nullifyDeleteRule
        recordRelation.isOptional = false

        detailsRelation.inverseRelationship = recordRelation
        recordRelation.inverseRelationship = detailsRelation

        recordEntity.properties.append(detailsRelation)
        detailEntity.properties.append(recordRelation)

        model.entities = [recordEntity, detailEntity]
        return model
    }
}
