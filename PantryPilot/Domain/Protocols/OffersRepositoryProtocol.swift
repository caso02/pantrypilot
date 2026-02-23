import Foundation

protocol OffersRepositoryProtocol {
    func fetchOffers() async throws -> [Offer]
}
