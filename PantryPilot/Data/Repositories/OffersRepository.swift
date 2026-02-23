import Foundation

final class OffersRepository: OffersRepositoryProtocol {
    func fetchOffers() async throws -> [Offer] {
        // TODO: Connect to real API when backend available
        return [
            Offer(
                merchantId: UUID(),
                name: "M-Classic Vollmilch",
                startsAt: .now,
                endsAt: Calendar.current.date(byAdding: .day, value: 7, to: .now)!,
                discountText: "-20%"
            ),
            Offer(
                merchantId: UUID(),
                name: "Pouletbrust",
                startsAt: .now,
                endsAt: Calendar.current.date(byAdding: .day, value: 3, to: .now)!,
                discountText: "2 für 1"
            ),
        ]
    }
}
