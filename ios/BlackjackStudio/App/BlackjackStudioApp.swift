import SwiftUI

@main
struct BlackjackStudioApp: App {
    @StateObject private var model = StudioModel()
    @StateObject private var purchases = PurchaseStore()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(model).environmentObject(purchases)
                .tint(StudioTheme.accent)
                .task { await purchases.start() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await purchases.refresh() } }
                    if phase == .background { Task { await model.flushProgress() } }
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var model: StudioModel
    @EnvironmentObject private var purchases: PurchaseStore
    var body: some View {
        Group {
            if model.snapshot.preferences.hasOnboarded {
                TabView(selection: $model.selectedTab) {
                    NavigationStack { TrainScreen() }.tabItem { Label("Train", systemImage: "square.grid.2x2") }.tag(0)
                    LearnScreen(hasPro: purchases.hasPro, completedLessons: model.snapshot.completedLessons,
                        onComplete: model.completeLesson, onUpgrade: { model.showPaywall = true }).tabItem { Label("Learn", systemImage: "book.closed") }.tag(1)
                    NavigationStack { TableScreen() }.tabItem { Label("Table", systemImage: "suit.spade") }.tag(2)
                    NavigationStack { ProgressScreen() }.tabItem { Label("Progress", systemImage: "chart.xyaxis.line") }.tag(3)
                }
                .toolbarBackground(StudioTheme.surface, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
                .fullScreenCover(item: $model.activeDrill) { kind in
                    DrillSessionView(kind: kind, onFinish: model.finish, hapticsEnabled: model.snapshot.preferences.haptics)
                }
                .sheet(isPresented: $model.showPaywall) { PaywallView() }
                .sheet(isPresented: $model.showSettings) { SettingsScreen() }
            } else { OnboardingScreen() }
        }
        .alert("Local progress", isPresented: Binding(get: { model.storageMessage != nil }, set: { if !$0 { model.storageMessage = nil } })) {
            Button("OK") { model.storageMessage = nil }
        } message: { Text(model.storageMessage ?? "") }
    }
}
