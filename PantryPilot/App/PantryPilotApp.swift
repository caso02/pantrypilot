import SwiftUI
import SwiftData
import GoogleSignIn

@main
struct PantryPilotApp: App {
    @UIApplicationDelegateAdaptor(PushNotificationDelegate.self) var appDelegate

    @State private var sessionStore = SessionStore()
    @State private var inventoryStore: InventoryStore

    private let container: DependencyContainer

    init() {
        if let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }
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
                if !sessionStore.isAuthenticated {
                    SignInView(sessionStore: sessionStore)
                } else if sessionStore.shouldShowOnboardingAfterSignIn {
                    OnboardingView(
                        hasCompletedOnboarding: Binding(
                            get: { sessionStore.shouldShowOnboardingAfterSignIn },
                            set: { completed in
                                if completed {
                                    sessionStore.completeOnboardingAfterSignIn()
                                }
                            }
                        )
                    )
                } else {
                    MainTabView(
                        sessionStore: sessionStore,
                        inventoryStore: inventoryStore,
                        container: container
                    )
                }
            }
            .animation(.easeInOut(duration: 0.3), value: sessionStore.isAuthenticated)
            .animation(.easeInOut(duration: 0.3), value: sessionStore.shouldShowOnboardingAfterSignIn)
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
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
                    Task {
                        await sync.pullFromCloud()
                        await sync.pushToCloud()
                    }
                } else {
                    inventoryStore.syncService = nil
                }
            }
        }
        .modelContainer(PersistenceController.shared.container)
    }
}
