import SwiftUI

/// The TV's installed apps, one tap to open.
struct AppsView: View {

    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        Haptics.tap()
                        model.openYouTube()
                    } label: {
                        Label("YouTube", systemImage: "play.rectangle.fill")
                            .foregroundStyle(RemotePalette.youTube)
                    }
                } footer: {
                    Text("Siri can do this too – try “Aliens on the telly”.")
                }

                Section("On your TV") {
                    if model.apps.isEmpty {
                        if model.isLoadingApps {
                            HStack(spacing: 12) {
                                ProgressView()
                                Text("Asking the TV…")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text(model.appsError ?? "Pull down to load the list from the TV.")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ForEach(model.apps) { app in
                            Button {
                                Haptics.tap()
                                model.launch(app)
                            } label: {
                                HStack {
                                    Text(app.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "arrow.up.forward.app")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if let error = model.appsError, !model.apps.isEmpty {
                    Section {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Apps")
            .refreshable {
                await model.loadApps()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await model.loadApps() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(model.isLoadingApps)
                    .accessibilityLabel(Text("Reload apps"))
                }
            }
            .task {
                await model.loadAppsIfNeeded()
            }
            .bannerOverlay()
        }
    }
}
