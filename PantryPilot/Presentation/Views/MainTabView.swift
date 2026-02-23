import SwiftUI

struct MainTabView: View {
    let sessionStore: SessionStore
    let inventoryStore: InventoryStore
    let container: DependencyContainer

    var body: some View {
        TabView {
            InventoryView(store: inventoryStore)
                .tabItem { Label("Inventar", systemImage: "refrigerator.fill") }
                .tag(0)

            ScanTabView(
                receiptRepository: container.receiptRepository,
                normalizationService: container.normalizationService,
                expiryService: container.expiryEstimationService,
                store: inventoryStore,
                useMockAPI: container.useMockAPI,
                notificationManager: container.notificationManager,
                ocrService: container.ocrService
            )
            .tabItem { Label("Scan", systemImage: "doc.text.viewfinder") }
            .tag(1)

            ShoppingListView(
                store: inventoryStore,
                lowStockService: container.lowStockService
            )
            .tabItem { Label("Einkaufsliste", systemImage: "cart.fill") }
            .tag(2)

            InsightsView(store: inventoryStore)
                .tabItem { Label("Übersicht", systemImage: "chart.bar.fill") }
                .tag(3)

            SettingsView(
                sessionStore: sessionStore,
                notificationManager: container.notificationManager
            )
            .tabItem { Label("Einstellungen", systemImage: "gearshape.fill") }
            .tag(4)
        }
    }
}
