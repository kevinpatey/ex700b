import SwiftUI
import UIKit

/// Little taps so the remote feels like a remote.
enum Haptics {
    @MainActor static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    @MainActor static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

/// Shared colours.
enum RemotePalette {
    static var key: Color { Color(.secondarySystemBackground) }
    static var panel: Color { Color(.secondarySystemBackground) }
    static var power: Color { Color(red: 0.86, green: 0.18, blue: 0.20) }
    static var youTube: Color { Color(red: 0.93, green: 0.11, blue: 0.14) }
    static var red: Color { Color(red: 0.90, green: 0.22, blue: 0.21) }
    static var green: Color { Color(red: 0.20, green: 0.66, blue: 0.33) }
    static var yellow: Color { Color(red: 0.98, green: 0.78, blue: 0.18) }
    static var blue: Color { Color(red: 0.16, green: 0.45, blue: 0.90) }
}

/// Shrinks slightly while pressed.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.55 : 1)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// A rounded remote-control key.
struct RemoteKeyStyle: ButtonStyle {
    var fill: Color = RemotePalette.key
    var foreground: Color = .primary
    var height: CGFloat = 50

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
            .background(fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.6 : 1)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// One button that sends one key.
struct KeyButton: View {
    @Environment(AppModel.self) private var model

    let command: TVCommand
    var title: String? = nil
    var systemImage: String? = nil
    var fill: Color = RemotePalette.key
    var foreground: Color = .primary
    var height: CGFloat = 50

    var body: some View {
        Button {
            Haptics.tap()
            model.press(command)
        } label: {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
            } else {
                Text(title ?? command.title)
            }
        }
        .buttonStyle(RemoteKeyStyle(fill: fill, foreground: foreground, height: height))
        .accessibilityLabel(Text(command.title))
    }
}

/// Up/down/left/right with OK in the middle.
struct DirectionPad: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            Circle()
                .fill(RemotePalette.panel)

            VStack(spacing: 0) {
                arrow(.up, systemImage: "chevron.up")

                HStack(spacing: 0) {
                    arrow(.left, systemImage: "chevron.left")

                    Button {
                        tap(.enter)
                    } label: {
                        Text("OK")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 86, height: 86)
                            .background(Circle().fill(Color.accentColor))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel(Text("OK"))

                    arrow(.right, systemImage: "chevron.right")
                }

                arrow(.down, systemImage: "chevron.down")
            }
        }
        .frame(width: 244, height: 244)
    }

    private func arrow(_ command: TVCommand, systemImage: String) -> some View {
        Button {
            tap(command)
        } label: {
            Image(systemName: systemImage)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
                .frame(width: 76, height: 76)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(Text(command.title))
    }

    private func tap(_ command: TVCommand) {
        Haptics.tap()
        model.press(command)
    }
}

/// A tall +/− rocker, like volume and channel on a real remote.
struct Rocker: View {
    @Environment(AppModel.self) private var model

    let label: String
    let up: TVCommand
    let down: TVCommand
    var upImage = "plus"
    var downImage = "minus"

    var body: some View {
        VStack(spacing: 0) {
            button(up, systemImage: upImage)
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            button(down, systemImage: downImage)
        }
        .frame(width: 86)
        .background(RemotePalette.panel, in: Capsule())
    }

    private func button(_ command: TVCommand, systemImage: String) -> some View {
        Button {
            Haptics.tap()
            model.press(command)
        } label: {
            Image(systemName: systemImage)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, minHeight: 62)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(Text(command.title))
    }
}

/// Small message bar at the bottom of the screen.
struct BannerBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let banner = model.banner {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: banner.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(banner.isError ? Color.orange : Color.green)
                Text(banner.text)
                    .font(.footnote)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    model.dismissBanner()
                } label: {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel(Text("Dismiss"))
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

extension View {
    /// Shows the app's message bar above the tab bar.
    func bannerOverlay() -> some View {
        safeAreaInset(edge: .bottom) {
            BannerBar()
        }
    }
}
