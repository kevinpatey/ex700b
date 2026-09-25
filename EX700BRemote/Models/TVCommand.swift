import Foundation

/// Every remote-control button the app can press.
/// Key codes are Panasonic's "NRC_…-ONOFF" names.
enum TVCommand: String, CaseIterable, Sendable, Identifiable {

    // Power and inputs
    case power
    case input
    case tv
    case hdmi1
    case hdmi2
    case hdmi3
    case hdmi4

    // Menus
    case home
    case apps
    case menu
    case guide
    case info
    case option
    case back
    case exit

    // Navigation
    case up
    case down
    case left
    case right
    case enter

    // Sound
    case volumeUp
    case volumeDown
    case mute

    // Channels
    case channelUp
    case channelDown
    case lastView

    // Playback
    case play
    case pause
    case stop
    case rewind
    case fastForward
    case previous
    case next
    case record

    // Colour keys
    case red
    case green
    case yellow
    case blue

    // Teletext and subtitles
    case text
    case subtitles

    // Numbers
    case zero
    case one
    case two
    case three
    case four
    case five
    case six
    case seven
    case eight
    case nine

    var id: String { rawValue }

    /// The key code the TV expects inside <X_KeyEvent>.
    var panasonicKey: String {
        switch self {
        case .power: return "NRC_POWER-ONOFF"
        case .input: return "NRC_CHG_INPUT-ONOFF"
        case .tv: return "NRC_TV-ONOFF"
        case .hdmi1: return "NRC_HDMI1-ONOFF"
        case .hdmi2: return "NRC_HDMI2-ONOFF"
        case .hdmi3: return "NRC_HDMI3-ONOFF"
        case .hdmi4: return "NRC_HDMI4-ONOFF"

        case .home: return "NRC_HOME-ONOFF"
        case .apps: return "NRC_APPS-ONOFF"
        case .menu: return "NRC_MENU-ONOFF"
        case .guide: return "NRC_EPG-ONOFF"
        case .info: return "NRC_INFO-ONOFF"
        case .option: return "NRC_SUBMENU-ONOFF"
        case .back: return "NRC_RETURN-ONOFF"
        case .exit: return "NRC_CANCEL-ONOFF"

        case .up: return "NRC_UP-ONOFF"
        case .down: return "NRC_DOWN-ONOFF"
        case .left: return "NRC_LEFT-ONOFF"
        case .right: return "NRC_RIGHT-ONOFF"
        case .enter: return "NRC_ENTER-ONOFF"

        case .volumeUp: return "NRC_VOLUP-ONOFF"
        case .volumeDown: return "NRC_VOLDOWN-ONOFF"
        case .mute: return "NRC_MUTE-ONOFF"

        case .channelUp: return "NRC_CH_UP-ONOFF"
        case .channelDown: return "NRC_CH_DOWN-ONOFF"
        case .lastView: return "NRC_R_TUNE-ONOFF"

        case .play: return "NRC_PLAY-ONOFF"
        case .pause: return "NRC_PAUSE-ONOFF"
        case .stop: return "NRC_STOP-ONOFF"
        case .rewind: return "NRC_REW-ONOFF"
        case .fastForward: return "NRC_FF-ONOFF"
        case .previous: return "NRC_SKIP_PREV-ONOFF"
        case .next: return "NRC_SKIP_NEXT-ONOFF"
        case .record: return "NRC_REC-ONOFF"

        case .red: return "NRC_RED-ONOFF"
        case .green: return "NRC_GREEN-ONOFF"
        case .yellow: return "NRC_YELLOW-ONOFF"
        case .blue: return "NRC_BLUE-ONOFF"

        case .text: return "NRC_TEXT-ONOFF"
        case .subtitles: return "NRC_STTL-ONOFF"

        case .zero: return "NRC_D0-ONOFF"
        case .one: return "NRC_D1-ONOFF"
        case .two: return "NRC_D2-ONOFF"
        case .three: return "NRC_D3-ONOFF"
        case .four: return "NRC_D4-ONOFF"
        case .five: return "NRC_D5-ONOFF"
        case .six: return "NRC_D6-ONOFF"
        case .seven: return "NRC_D7-ONOFF"
        case .eight: return "NRC_D8-ONOFF"
        case .nine: return "NRC_D9-ONOFF"
        }
    }

    /// Human-readable name, used for messages and accessibility.
    var title: String {
        switch self {
        case .power: return "Power"
        case .input: return "Input"
        case .tv: return "TV"
        case .hdmi1: return "HDMI 1"
        case .hdmi2: return "HDMI 2"
        case .hdmi3: return "HDMI 3"
        case .hdmi4: return "HDMI 4"
        case .home: return "Home"
        case .apps: return "Apps"
        case .menu: return "Menu"
        case .guide: return "Guide"
        case .info: return "Info"
        case .option: return "Option"
        case .back: return "Back"
        case .exit: return "Exit"
        case .up: return "Up"
        case .down: return "Down"
        case .left: return "Left"
        case .right: return "Right"
        case .enter: return "OK"
        case .volumeUp: return "Volume up"
        case .volumeDown: return "Volume down"
        case .mute: return "Mute"
        case .channelUp: return "Channel up"
        case .channelDown: return "Channel down"
        case .lastView: return "Last view"
        case .play: return "Play"
        case .pause: return "Pause"
        case .stop: return "Stop"
        case .rewind: return "Rewind"
        case .fastForward: return "Fast forward"
        case .previous: return "Previous"
        case .next: return "Next"
        case .record: return "Record"
        case .red: return "Red"
        case .green: return "Green"
        case .yellow: return "Yellow"
        case .blue: return "Blue"
        case .text: return "Text"
        case .subtitles: return "Subtitles"
        case .zero: return "0"
        case .one: return "1"
        case .two: return "2"
        case .three: return "3"
        case .four: return "4"
        case .five: return "5"
        case .six: return "6"
        case .seven: return "7"
        case .eight: return "8"
        case .nine: return "9"
        }
    }

    /// Number keys 0–9 in order.
    static let digits: [TVCommand] = [
        .zero, .one, .two, .three, .four,
        .five, .six, .seven, .eight, .nine
    ]
}
