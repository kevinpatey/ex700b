import SwiftUI

/// Tools for poking at the TV directly.
struct PanasonicLabView: View {

    @Environment(AppModel.self) private var model

    @State private var output = ""
    @State private var isBusy = false
    @State private var text = ""
    @State private var keyCode = "NRC_HDMI1-ONOFF"
    @State private var service: TVService = .networkControl
    @State private var rawAction = "X_GetAppList"
    @State private var rawArguments = ""

    var body: some View {
        Form {
            Section("TV") {
                LabeledContent("Name", value: model.tv.name)
                LabeledContent("Address", value: "\(model.tv.host):\(model.tv.port)")
                if let udn = model.tv.udn {
                    Text(udn)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            Section("Ask the TV") {
                Button("Device description") {
                    run {
                        let info = try await $0.deviceInfo()
                        return """
                        Name: \(info.friendlyName)
                        Maker: \(info.manufacturer)
                        Model name: \(info.modelName)
                        Model number: \(info.modelNumber)
                        UDN: \(info.udn ?? "–")
                        """
                    }
                }
                Button("Supported commands") {
                    run {
                        let actions = try await $0.supportedActions()
                        return actions.isEmpty ? "No actions listed." : actions.joined(separator: "\n")
                    }
                }
                Button("Power state and volume") {
                    run { controller in
                        switch await controller.powerState() {
                        case .on(let volume, let muted):
                            let level = volume.map { String($0) } ?? "?"
                            let mute = muted.map { $0 ? "yes" : "no" } ?? "?"
                            return "On. Volume \(level), muted: \(mute)."
                        case .standby:
                            return "Standby (the TV answered but its media renderer is off)."
                        case .unreachable(let error):
                            return error.errorDescription ?? "Unreachable."
                        }
                    }
                }
                Button("App list") {
                    run {
                        let apps = try await $0.fetchApps()
                        return apps.map { "\($0.name) – \($0.launchKeyword)" }.joined(separator: "\n")
                    }
                }
            }

            Section {
                TextField("NRC_…-ONOFF", text: $keyCode)
                    .font(.body.monospaced())
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                Button("Send key") {
                    let code = keyCode
                    run {
                        try await $0.sendKey(code)
                        return "Sent \(code)."
                    }
                }
            } header: {
                Text("Any key code")
            } footer: {
                Text("For example NRC_HDMI2-ONOFF, NRC_GUIDE-ONOFF or NRC_ASPECT-ONOFF.")
            }

            Section {
                TextField("Text to type on the TV", text: $text)
                Button("Send text") {
                    let value = text
                    run {
                        try await $0.sendText(value)
                        return "Sent “\(value)”."
                    }
                }
                .disabled(text.isEmpty)
            } header: {
                Text("Keyboard")
            } footer: {
                Text("Open a search box on the TV first (e.g. in YouTube), then send.")
            }

            Section {
                Picker("Service", selection: $service) {
                    ForEach(TVService.allCases) { service in
                        Text(service.title).tag(service)
                    }
                }
                TextField("Action, e.g. X_GetAppList", text: $rawAction)
                    .font(.body.monospaced())
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextEditor(text: $rawArguments)
                    .font(.footnote.monospaced())
                    .frame(minHeight: 80)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Send SOAP") {
                    let chosenService = service
                    let action = rawAction
                    let arguments = rawArguments
                    run {
                        try await $0.rawSOAP(service: chosenService, action: action, arguments: arguments)
                    }
                }
            } header: {
                Text("Raw SOAP")
            } footer: {
                Text("Arguments go inside the action element, e.g. <InstanceID>0</InstanceID><Channel>Master</Channel> for GetVolume.")
            }

            Section("Output") {
                if isBusy {
                    ProgressView()
                }
                Text(output.isEmpty ? "No result yet." : output)
                    .font(.footnote.monospaced())
                    .textSelection(.enabled)
            }
        }
        .navigationTitle("Panasonic Lab")
    }

    private func run(_ operation: @escaping (PanasonicController) async throws -> String) {
        isBusy = true
        output = ""
        let controller = model.labController
        Task {
            output = await model.labRun {
                try await operation(controller)
            }
            isBusy = false
        }
    }
}
