import AppIntents
import SwiftUI

/// Connect to the TV, one-time TV settings, and Siri help.
struct SetupView: View {

    @Environment(AppModel.self) private var model

    @State private var addressText = ""
    @State private var addressInvalid = false
    @FocusState private var addressFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                tvSection
                findSection
                testSection
                tvSettingsSection
                siriSection
                aboutSection
            }
            .navigationTitle("Setup")
            .onAppear {
                addressText = model.tv.host
            }
            .onChange(of: model.tv.host) { _, newHost in
                if !addressFocused {
                    addressText = newHost
                }
            }
            .bannerOverlay()
        }
    }

    // MARK: - Sections

    private var tvSection: some View {
        Section {
            LabeledContent("Name", value: model.tv.name)
            LabeledContent("Model", value: model.tv.model)

            HStack {
                Text("IP address")
                Spacer()
                TextField("192.168.1.158", text: $addressText)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numbersAndPunctuation)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($addressFocused)
                    .onSubmit(saveAddress)
            }

            if addressText.trimmingCharacters(in: .whitespaces) != model.tv.host {
                Button("Save address", action: saveAddress)
            }
        } header: {
            Text("Your TV")
        } footer: {
            if addressInvalid {
                Text("That doesn't look like an IP address (it should be like 192.168.1.158).")
                    .foregroundStyle(.red)
            } else {
                Text("Tip: ask your router to always give the TV the same address (a “DHCP reservation”). If it does move, the app searches for it by itself.")
            }
        }
    }

    private var findSection: some View {
        Section {
            Button {
                addressFocused = false
                model.startScan()
            } label: {
                HStack {
                    Label(
                        model.isScanning ? "Searching your Wi-Fi…" : "Search Wi-Fi for the TV",
                        systemImage: "dot.radiowaves.left.and.right"
                    )
                    Spacer()
                    if model.isScanning {
                        ProgressView()
                    }
                }
            }
            .disabled(model.isScanning)

            if model.isScanning {
                ProgressView(value: model.scanProgress)
            }

            ForEach(model.scanResults) { found in
                Button {
                    model.use(found)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(found.info.friendlyName)
                                .foregroundStyle(.primary)
                            Text("\(found.info.model) · \(found.host)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if found.host == model.tv.host && found.port == model.tv.port {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Text("Use")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
            }

            if let message = model.scanMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Find your TV")
        } footer: {
            Text("The TV needs to be on (or in network standby) and on the same Wi-Fi as your phone. The first time, iPhone asks to allow local network access – tap Allow.")
        }
    }

    private var testSection: some View {
        Section("Check the connection") {
            Button {
                Task { await model.runConnectionTest() }
            } label: {
                HStack {
                    Label("Test connection", systemImage: "stethoscope")
                    Spacer()
                    if model.isTesting {
                        ProgressView()
                    }
                }
            }
            .disabled(model.isTesting)

            ForEach(model.report) { line in
                Label {
                    Text(line.text)
                        .font(.footnote)
                } icon: {
                    Image(systemName: line.ok ? "checkmark.circle.fill" : "xmark.octagon.fill")
                        .foregroundStyle(line.ok ? Color.green : Color.red)
                }
            }
        }
    }

    private var tvSettingsSection: some View {
        Section {
            SetupStep(number: 1, text: "On the TV remote press Menu, then go to Network › TV Remote App Settings.")
            SetupStep(number: 2, text: "Set “TV Remote” to On – this lets the app send buttons.")
            SetupStep(number: 3, text: "Set “Powered On by Apps” to On – this lets the app (and Siri) switch the TV on from standby.")
            SetupStep(number: 4, text: "If you see “Wake on Wireless LAN” or “Networked Standby”, switch that on too.")
        } header: {
            Text("One-time TV settings")
        } footer: {
            Text("Menu names can differ slightly between firmware versions. With “Powered On by Apps” on, the TV's standby light glows orange.")
        }
    }

    private var siriSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("Just say “Hey Siri”, then:")
                    .font(.subheadline.weight(.semibold))
                ForEach(Self.siriExamples, id: \.self) { phrase in
                    Text("• \(phrase)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 6) {
                Text("Want just “Hey Siri, Aliens”?")
                    .font(.subheadline.weight(.semibold))
                Text("Open the Shortcuts app, tap +, add the “Aliens” action from EX700B Remote, and rename the shortcut to “Aliens”. Siri runs any of your shortcuts when you say its name.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

            ShortcutsLink()
        } header: {
            Text("Siri")
        } footer: {
            Text("Siri knows this app as “Telly” too. The phrases start working once you’ve opened the app at least once – nothing else to set up. “Aliens” switches the TV on first if it’s in standby.")
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("App", value: "EX700B Remote \(Self.appVersion)")
            LabeledContent("Address", value: model.tv.address)
            LabeledContent("Port", value: String(model.tv.port))
        }
    }

    // MARK: - Helpers

    private func saveAddress() {
        addressFocused = false
        addressInvalid = !model.updateAddress(addressText)
        if !addressInvalid {
            addressText = model.tv.host
        }
    }

    static let siriExamples = [
        "Turn on the telly",
        "Turn off the telly",
        "Turn the telly up / down",
        "Mute the telly",
        "Pause the telly",
        "Aliens on the telly"
    ]

    static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

/// A numbered instruction row.
struct SetupStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.accentColor))
            Text(text)
                .font(.subheadline)
        }
        .padding(.vertical, 2)
    }
}
