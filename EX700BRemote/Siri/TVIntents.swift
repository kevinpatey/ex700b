import AppIntents
import Foundation

// Siri and Shortcuts actions.
//
// Rules Apple enforces when building (these caused the earlier build errors):
//  • Every App Shortcut phrase must contain \(.applicationName) exactly once.
//    That token matches the app's name "EX700B Remote" AND its Siri nickname
//    "Telly" (INAlternativeAppNames in Info.plist), so
//    "Turn on the \(.applicationName)" works as "Turn on the telly".
//  • At most 10 AppShortcut entries.
// For a phrase with no app name at all (like just "Aliens"), make a personal
// shortcut in the Shortcuts app – see the Setup tab.

// MARK: - Power

struct TurnTVOnIntent: AppIntent {
    static let title: LocalizedStringResource = "Turn TV On"
    static let description = IntentDescription("Switches the Panasonic TV on. Does nothing if it's already on.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let change = try await PanasonicController.shared.turnOn()
        if change == .alreadyOn {
            return .result(dialog: "The TV is already on.")
        }
        return .result(dialog: "Turning the TV on.")
    }
}

struct TurnTVOffIntent: AppIntent {
    static let title: LocalizedStringResource = "Turn TV Off"
    static let description = IntentDescription("Switches the Panasonic TV to standby. Does nothing if it's already off.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let change = try await PanasonicController.shared.turnOff()
        switch change {
        case .alreadyOff:
            return .result(dialog: "The TV is already off.")
        case .noResponse:
            return .result(dialog: "The TV isn't answering, so it's probably off already.")
        default:
            return .result(dialog: "Turning the TV off.")
        }
    }
}

// MARK: - Volume

struct TVVolumeUpIntent: AppIntent {
    static let title: LocalizedStringResource = "Turn TV Volume Up"
    static let description = IntentDescription("Turns the TV's volume up a few steps.")

    @Parameter(title: "Steps", default: 5)
    var steps: Int

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let amount = max(1, min(steps, 50))
        if let level = try await PanasonicController.shared.changeVolume(by: amount) {
            return .result(dialog: "Volume \(level).")
        }
        return .result(dialog: "Turned it up.")
    }
}

struct TVVolumeDownIntent: AppIntent {
    static let title: LocalizedStringResource = "Turn TV Volume Down"
    static let description = IntentDescription("Turns the TV's volume down a few steps.")

    @Parameter(title: "Steps", default: 5)
    var steps: Int

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let amount = max(1, min(steps, 50))
        if let level = try await PanasonicController.shared.changeVolume(by: -amount) {
            return .result(dialog: "Volume \(level).")
        }
        return .result(dialog: "Turned it down.")
    }
}

struct SetTVVolumeIntent: AppIntent {
    static let title: LocalizedStringResource = "Set TV Volume"
    static let description = IntentDescription("Sets the TV's volume to an exact level from 0 to 100.")

    @Parameter(title: "Volume")
    var level: Int

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let clamped = max(0, min(level, 100))
        try await PanasonicController.shared.setVolume(clamped)
        return .result(dialog: "Volume \(clamped).")
    }
}

struct TVMuteIntent: AppIntent {
    static let title: LocalizedStringResource = "Mute TV"
    static let description = IntentDescription("Mutes the TV.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await setMuted(true)
        return .result(dialog: "Muted.")
    }
}

struct TVUnmuteIntent: AppIntent {
    static let title: LocalizedStringResource = "Unmute TV"
    static let description = IntentDescription("Turns the TV's sound back on.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await setMuted(false)
        return .result(dialog: "Sound's back on.")
    }
}

/// Uses the exact mute setting when the TV supports it, otherwise the
/// Mute button (a toggle).
private func setMuted(_ muted: Bool) async throws {
    let controller = PanasonicController.shared
    do {
        try await controller.setMuted(muted)
    } catch let error as PanasonicError where error.isConnectionProblem {
        throw error
    } catch {
        try await controller.send(.mute)
    }
}

// MARK: - Apps

struct YouTubeIntent: AppIntent {
    static let title: LocalizedStringResource = "Open YouTube on TV"
    static let description = IntentDescription("Opens YouTube on the Panasonic TV, switching it on first if needed.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let wokeUp = try await PanasonicController.shared.wakeAndLaunchYouTube()
        if wokeUp {
            return .result(dialog: "Switching the TV on and opening YouTube.")
        }
        return .result(dialog: "Opening YouTube on the TV.")
    }
}

// 👽 THE IMPORTANT ONE.
struct AliensIntent: AppIntent {
    static let title: LocalizedStringResource = "Aliens"
    static let description = IntentDescription("Switches the TV on if needed and opens YouTube. The truth is out there.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let wokeUp = try await PanasonicController.shared.wakeAndLaunchYouTube()
        if wokeUp {
            return .result(dialog: "Waking the TV and opening YouTube. The truth is out there.")
        }
        return .result(dialog: "Opening YouTube. The truth is out there.")
    }
}

struct OpenTVAppIntent: AppIntent {
    static let title: LocalizedStringResource = "Open App on TV"
    static let description = IntentDescription("Opens an app on the TV by name, for example Netflix or BBC iPlayer.")

    @Parameter(title: "App name")
    var appName: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let controller = PanasonicController.shared
        try await controller.ensureOn()
        let app = try await controller.launchApp(named: appName)
        return .result(dialog: "Opening \(app.name).")
    }
}

// MARK: - Playback

struct TVPlayIntent: AppIntent {
    static let title: LocalizedStringResource = "Play TV"
    static let description = IntentDescription("Presses Play on the TV.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await PanasonicController.shared.send(.play)
        return .result(dialog: "Playing.")
    }
}

struct TVPauseIntent: AppIntent {
    static let title: LocalizedStringResource = "Pause TV"
    static let description = IntentDescription("Presses Pause on the TV.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await PanasonicController.shared.send(.pause)
        return .result(dialog: "Paused.")
    }
}

// MARK: - Any button (for your own shortcuts)

struct PressTVButtonIntent: AppIntent {
    static let title: LocalizedStringResource = "Press TV Button"
    static let description = IntentDescription("Presses any button on the TV remote, one or more times.")

    @Parameter(title: "Button")
    var button: TVButton

    @Parameter(title: "Times", default: 1)
    var times: Int

    func perform() async throws -> some IntentResult {
        try await PanasonicController.shared.press(button.command, times: max(1, min(times, 50)))
        return .result()
    }
}

enum TVButton: String, AppEnum, CaseIterable {
    case power, input, tv, hdmi1, hdmi2, hdmi3, hdmi4
    case home, apps, menu, guide, info, option, back, exit
    case up, down, left, right, enter
    case volumeUp, volumeDown, mute
    case channelUp, channelDown, lastView
    case play, pause, stop, rewind, fastForward, previous, next, record
    case red, green, yellow, blue
    case text, subtitles
    case zero, one, two, three, four, five, six, seven, eight, nine

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "TV Button"

    static let caseDisplayRepresentations: [TVButton: DisplayRepresentation] = [
        .power: "Power",
        .input: "Input",
        .tv: "TV",
        .hdmi1: "HDMI 1",
        .hdmi2: "HDMI 2",
        .hdmi3: "HDMI 3",
        .hdmi4: "HDMI 4",
        .home: "Home",
        .apps: "Apps",
        .menu: "Menu",
        .guide: "Guide",
        .info: "Info",
        .option: "Option",
        .back: "Back",
        .exit: "Exit",
        .up: "Up",
        .down: "Down",
        .left: "Left",
        .right: "Right",
        .enter: "OK",
        .volumeUp: "Volume Up",
        .volumeDown: "Volume Down",
        .mute: "Mute",
        .channelUp: "Channel Up",
        .channelDown: "Channel Down",
        .lastView: "Last View",
        .play: "Play",
        .pause: "Pause",
        .stop: "Stop",
        .rewind: "Rewind",
        .fastForward: "Fast Forward",
        .previous: "Previous",
        .next: "Next",
        .record: "Record",
        .red: "Red",
        .green: "Green",
        .yellow: "Yellow",
        .blue: "Blue",
        .text: "Text",
        .subtitles: "Subtitles",
        .zero: "0",
        .one: "1",
        .two: "2",
        .three: "3",
        .four: "4",
        .five: "5",
        .six: "6",
        .seven: "7",
        .eight: "8",
        .nine: "9"
    ]

    /// Same raw values as TVCommand.
    var command: TVCommand {
        TVCommand(rawValue: rawValue) ?? .enter
    }
}

// MARK: - Siri phrases (no setup needed)

struct EX700BShortcuts: AppShortcutsProvider {

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TurnTVOnIntent(),
            phrases: [
                "Turn on the \(.applicationName)",
                "Turn the \(.applicationName) on",
                "Switch on the \(.applicationName)",
                "Switch the \(.applicationName) on",
                "\(.applicationName) on",
                "Turn on the TV with \(.applicationName)"
            ],
            shortTitle: "Turn On",
            systemImageName: "power"
        )

        AppShortcut(
            intent: TurnTVOffIntent(),
            phrases: [
                "Turn off the \(.applicationName)",
                "Turn the \(.applicationName) off",
                "Switch off the \(.applicationName)",
                "Switch the \(.applicationName) off",
                "\(.applicationName) off",
                "Turn off the TV with \(.applicationName)"
            ],
            shortTitle: "Turn Off",
            systemImageName: "power.circle"
        )

        AppShortcut(
            intent: TVVolumeUpIntent(),
            phrases: [
                "Turn up the \(.applicationName)",
                "Turn the \(.applicationName) up",
                "\(.applicationName) louder",
                "Turn the TV up with \(.applicationName)"
            ],
            shortTitle: "Volume Up",
            systemImageName: "speaker.wave.3.fill"
        )

        AppShortcut(
            intent: TVVolumeDownIntent(),
            phrases: [
                "Turn down the \(.applicationName)",
                "Turn the \(.applicationName) down",
                "\(.applicationName) quieter",
                "Turn the TV down with \(.applicationName)"
            ],
            shortTitle: "Volume Down",
            systemImageName: "speaker.wave.1.fill"
        )

        AppShortcut(
            intent: TVMuteIntent(),
            phrases: [
                "Mute the \(.applicationName)",
                "\(.applicationName) mute",
                "Mute the TV with \(.applicationName)"
            ],
            shortTitle: "Mute",
            systemImageName: "speaker.slash.fill"
        )

        AppShortcut(
            intent: TVUnmuteIntent(),
            phrases: [
                "Unmute the \(.applicationName)",
                "\(.applicationName) unmute",
                "Unmute the TV with \(.applicationName)"
            ],
            shortTitle: "Unmute",
            systemImageName: "speaker.wave.2.fill"
        )

        AppShortcut(
            intent: YouTubeIntent(),
            phrases: [
                "Open YouTube on the \(.applicationName)",
                "YouTube on the \(.applicationName)",
                "Put YouTube on the \(.applicationName)",
                "Open YouTube on the TV with \(.applicationName)"
            ],
            shortTitle: "YouTube",
            systemImageName: "play.rectangle.fill"
        )

        // 👽
        AppShortcut(
            intent: AliensIntent(),
            phrases: [
                "Aliens on the \(.applicationName)",
                "\(.applicationName) aliens",
                "Aliens with \(.applicationName)",
                "Show me aliens on the \(.applicationName)"
            ],
            shortTitle: "Aliens",
            systemImageName: "sparkles"
        )

        AppShortcut(
            intent: TVPlayIntent(),
            phrases: [
                "Play the \(.applicationName)",
                "Resume the \(.applicationName)",
                "\(.applicationName) play"
            ],
            shortTitle: "Play",
            systemImageName: "play.fill"
        )

        AppShortcut(
            intent: TVPauseIntent(),
            phrases: [
                "Pause the \(.applicationName)",
                "\(.applicationName) pause",
                "Pause the TV with \(.applicationName)"
            ],
            shortTitle: "Pause",
            systemImageName: "pause.fill"
        )
    }
}

// MARK: - What Siri says when something goes wrong

extension PanasonicError: CustomLocalizedStringResourceConvertible {
    var localizedStringResource: LocalizedStringResource {
        LocalizedStringResource(stringLiteral: errorDescription ?? "Something went wrong talking to the TV.")
    }
}
