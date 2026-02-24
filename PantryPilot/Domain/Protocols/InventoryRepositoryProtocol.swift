import Foundation

protocol InventoryRepositoryProtocol {
    func fetchAll() async throws -> [InventoryItem]
    func save(_ item: InventoryItem) async throws
    func saveAll(_ items: [InventoryItem]) async throws
    func replaceAll(with items: [InventoryItem]) async throws
    func delete(_ item: InventoryItem) async throws
    func update(_ item: InventoryItem) async throws
    func syncWithRemote() async throws
}
