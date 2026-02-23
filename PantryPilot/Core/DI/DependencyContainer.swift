import Foundation

@MainActor
final class DependencyContainer {
    static let shared = DependencyContainer()

    let useMockAPI: Bool
    let networkClient: NetworkClientProtocol
    let receiptRepository: ReceiptRepositoryProtocol
    let inventoryRepository: InventoryRepositoryProtocol
    let offersRepository: OffersRepositoryProtocol
    let normalizationService: NormalizationService
    let expiryEstimationService: ExpiryEstimationService
    let lowStockService: LowStockSuggestionService
    let notificationManager: NotificationManager
    let persistenceController: PersistenceController
    let ocrService: ReceiptOCRService

    static let defaultBackendURL: URL = {
        #if targetEnvironment(simulator)
        return URL(string: "http://localhost:3000")!
        #else
        return URL(string: "http://192.168.1.61:3000")!
        #endif
    }()

    private init() {
        self.useMockAPI = ProcessInfo.processInfo.environment["USE_MOCK_API"] == "1"
            || UserDefaults.standard.bool(forKey: "useMockAPI")

        self.ocrService = ReceiptOCRService()

        let backendURLString = UserDefaults.standard.string(forKey: "backendURL")
        let baseURL = URL(string: backendURLString ?? "") ?? Self.defaultBackendURL

        if useMockAPI {
            let mock = MockAPIClient()
            self.networkClient = mock
            self.receiptRepository = ReceiptRepository(client: mock)
        } else {
            let client = NetworkClient(baseURL: baseURL) {
                KeychainWrapper.loadString(forKey: "authToken")
            }
            self.networkClient = client
            self.receiptRepository = ReceiptRepository(client: client)
        }

        let pc = PersistenceController.shared
        self.persistenceController = pc
        self.inventoryRepository = InventoryRepository(persistence: pc)
        self.offersRepository = OffersRepository()

        let normService = NormalizationService()
        normService.loadUserMappings(from: pc.container.mainContext)
        self.normalizationService = normService

        self.expiryEstimationService = ExpiryEstimationService()
        self.lowStockService = LowStockSuggestionService()
        self.notificationManager = NotificationManager()
    }
}
