import Foundation
import SwiftData

@MainActor
final class PersistenceController {
    static let shared = PersistenceController()

    let container: ModelContainer

    init() {
        let schema = Schema([
            PersistedInventoryItem.self,
            PersistedShoppingListItem.self,
            PersistedNormalizationMapping.self,
            PersistedReceipt.self,
            PersistedReceiptLineItem.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            container = try ModelContainer(for: schema, configurations: [config])
            AppLogger.persistence.info("SwiftData container initialized")
        } catch {
            AppLogger.persistence.error("Failed to create persistent ModelContainer: \(error.localizedDescription)")
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                container = try ModelContainer(for: schema, configurations: [fallback])
                AppLogger.persistence.warning("Falling back to in-memory SwiftData container")
            } catch {
                preconditionFailure("Critical: unable to initialize any ModelContainer (\(error.localizedDescription))")
            }
        }
    }

    static func preview() -> PersistenceController {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.mainContext
        for item in PersistedInventoryItem.sampleItems {
            context.insert(item)
        }
        for item in PersistedShoppingListItem.sampleItems {
            context.insert(item)
        }
        return controller
    }

    private init(inMemory: Bool) {
        let schema = Schema([
            PersistedInventoryItem.self,
            PersistedShoppingListItem.self,
            PersistedNormalizationMapping.self,
            PersistedReceipt.self,
            PersistedReceiptLineItem.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            AppLogger.persistence.error("Failed to create preview ModelContainer: \(error.localizedDescription)")
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                container = try ModelContainer(for: schema, configurations: [fallback])
            } catch {
                preconditionFailure("Critical: unable to initialize preview ModelContainer (\(error.localizedDescription))")
            }
        }
    }
}
