import SwiftUI

struct RemoteView: View {

    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                StatusCard()

                // Power, input, home, apps
                HStack(spacing: 10) {
                    KeyButton(
                        command: .power,
                        systemImage: "power",
                        fill: RemotePalette.power,
                        foreground: .white
                    )
                    KeyButton(command: .input)
                    KeyButton(command: .home)
                    KeyButton(command: .apps)
                }

                HStack(spacing: 10) {
                    KeyButton(command: .menu)
                    KeyButton(command: .guide)
                    KeyButton(command: .info)
                    KeyButton(command: .option)
                }

                DirectionPad()

                HStack(spacing: 10) {
                    KeyButton(command: .back, title: "Back")
                    KeyButton(command: .exit, title: "Exit")
                }

                volumeAndChannels

                // Playback
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        KeyButton(command: .rewind, systemImage: "backward.fill")
                        KeyButton(command: .play, systemImage: "play.fill")
                        KeyButton(command: .pause, systemImage: "pause.fill")
                        KeyButton(command: .fastForward, systemImage: "forward.fill")
                    }
                    HStack(spacing: 10) {
                        KeyButton(command: .previous, systemImage: "backward.end.fill")
                        KeyButton(command: .stop, systemImage: "stop.fill")
                        KeyButton(command: .record, systemImage: "record.circle", foreground: RemotePalette.red)
                        KeyButton(command: .next, systemImage: "forward.end.fill")
                    }
                }

                Button {
                    Haptics.tap()
                    model.openYouTube()
                } label: {
                    Label("YouTube", systemImage: "play.rectangle.fill")
                        .font(.headline)
                }
                .buttonStyle(RemoteKeyStyle(fill: RemotePalette.youTube, foreground: .white, height: 56))

                // Colour keys
                HStack(spacing: 10) {
                    KeyButton(command: .red, title: " ", fill: RemotePalette.red, height: 34)
                    KeyButton(command: .green, title: " ", fill: RemotePalette.green, height: 34)
                    KeyButton(command: .yellow, title: " ", fill: RemotePalette.yellow, height: 34)
                    KeyButton(command: .blue, title: " ", fill: RemotePalette.blue, height: 34)
                }

                numberPad

                HStack(spacing: 10) {
                    KeyButton(command: .lastView, title: "Last view")
                    KeyButton(command: .tv, title: "TV")
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .bannerOverlay()
        .task {
            await model.refreshStatus()
        }
    }

    private var volumeAndChannels: some View {
        HStack(alignment: .center, spacing: 12) {
            Rocker(label: "VOL", up: .volumeUp, down: .volumeDown)

            VStack(spacing: 10) {
                Button {
                    Haptics.tap()
                    model.press(.mute)
                } label: {
                    Image(systemName: model.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.title2)
                        .foregroundStyle(model.isMuted ? Color.orange : Color.primary)
                        .frame(width: 64, height: 64)
                        .background(Circle().fill(RemotePalette.panel))
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(Text("Mute"))

                Text(model.volume.map { "Volume \($0)" } ?? " ")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Rocker(
                label: "CH",
                up: .channelUp,
                down: .channelDown,
                upImage: "chevron.up",
                downImage: "chevron.down"
            )
        }
    }

    private var numberPad: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                KeyButton(command: .one)
                KeyButton(command: .two)
                KeyButton(command: .three)
            }
            HStack(spacing: 10) {
                KeyButton(command: .four)
                KeyButton(command: .five)
                KeyButton(command: .six)
            }
            HStack(spacing: 10) {
                KeyButton(command: .seven)
                KeyButton(command: .eight)
                KeyButton(command: .nine)
            }
            HStack(spacing: 10) {
                KeyButton(command: .text, title: "Text")
                KeyButton(command: .zero)
                KeyButton(command: .subtitles, title: "Subtitles")
            }
        }
    }
}

/// TV name, on/standby state and volume, with a refresh button.
struct StatusCard: View {

    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(dotColour)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(model.tv.name)
                    .font(.headline)
                Text(statusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            Spacer(minLength: 8)

            Button {
                Task { await model.refreshStatus() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.headline)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(Text("Refresh"))
        }
        .padding(14)
        .background(RemotePalette.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var dotColour: Color {
        switch model.status {
        case .on: return .green
        case .standby: return .orange
        case .unreachable: return .red
        case .unknown, .checking: return .gray
        }
    }

    private var statusText: String {
        switch model.status {
        case .unknown:
            return "\(model.tv.model) · \(model.tv.address)"
        case .checking:
            return "Checking…"
        case .on(let volume, let muted):
            var text = "On"
            if let volume { text += " · Volume \(volume)" }
            if muted == true { text += " · Muted" }
            return text
        case .standby:
            return "Standby – press power to switch on"
        case .unreachable(let message):
            return message
        }
    }
}
