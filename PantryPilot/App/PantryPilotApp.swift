import SwiftUI
import SwiftData

@main
struct PantryPilotApp: App {
    @UIApplicationDelegateAdaptor(PushNotificationDelegate.self) var appDelegate

    @State private var sessionStore = SessionStore()
    @State private var inventoryStore: InventoryStore
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    private let container: DependencyContainer

    init() {
        let di = DependencyContainer.shared
        self.container = di
        _inventoryStore = State(initialValue: InventoryStore(
            repository: di.inventoryRepository,
            expiryService: di.expiryEstimationService,
            normalizationService: di.normalizationService,
            modelContext: di.persistenceController.container.mainContext
        ))
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if !hasCompletedOnboarding {
                    OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                } else {
                    MainTabView(
                        sessionStore: sessionStore,
                        inventoryStore: inventoryStore,
                        container: container
                    )
                }
            }
            .animation(.easeInOut(duration: 0.3), value: hasCompletedOnboarding)
            .task {
                await sessionStore.checkAppleCredentialState()
            }
            .onChange(of: sessionStore.isAuthenticated) { _, isAuth in
                if isAuth {
                    let sync = SyncService(
                        networkClient: container.networkClient,
                        store: inventoryStore
                    )
                    inventoryStore.syncService = sync
                    Task { await sync.pushToCloud() }
                } else {
                    inventoryStore.syncService = nil
                }
            }
        }
        .modelContainer(PersistenceController.shared.container)
    }
}
