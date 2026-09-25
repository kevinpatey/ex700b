import SwiftUI

struct ContentView: View {

    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            RemoteView()
                .tabItem {
                    Label("Remote", systemImage: "av.remote")
                }

            AppsView()
                .tabItem {
                    Label("Apps", systemImage: "square.grid.2x2")
                }

            SetupView()
                .tabItem {
                    Label("Setup", systemImage: "gearshape")
                }

            NavigationStack {
                PanasonicLabView()
            }
            .tabItem {
                Label("Lab", systemImage: "wrench.and.screwdriver")
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await model.refreshStatus() }
            }
        }
    }
}
