# EX700B Remote

An iPhone remote for the **Panasonic TX-50EX700B** that works over your home Wi-Fi, with Siri built in.
You can say "Hey Siri, turn on the telly", "Mute the telly", or 👽 "Aliens on the telly".

- **Remote tab:** power, input, home, apps, the D-pad, volume and channel rockers, playback, colour keys, numbers, text and subtitles. It also shows whether the TV is on and what the volume is.
- **Apps tab:** every app on the TV, read from the TV itself. Tap one to open it.
- **Setup tab:** finds the TV on your Wi-Fi automatically, tests the connection, lists the TV settings to switch on, and has help for Siri.
- **Lab tab:** tools for poking at the TV directly: any key code, text input, raw SOAP commands, and the TV's list of supported commands.
- **Siri and Shortcuts:** ten built-in voice phrases, plus actions for the Shortcuts app (press any button, open any app, set the volume).
- If the router gives the TV a new IP address, the app finds it again by itself.

---

## 1. Build it on Codemagic

1. Push this repository to GitHub (`git push`).
2. In Codemagic, open the app and click **Start new build**. Pick the **ios-native-build** workflow on the `main` branch.
3. After about 5–10 minutes, open the finished build and download **EX700BRemote.ipa** from **Artifacts**.

The build doesn't need a paid Apple Developer account. It makes an *unsigned* app, and Sideloadly signs it with your own Apple ID.

If a build ever fails, the "Build the app" step prints the exact errors, and `xcodebuild.log` is saved under Artifacts too.

## 2. Install it with Sideloadly (free Apple ID)

1. Install **Sideloadly** on your PC from sideloadly.io. On Windows you also need the **iTunes** and **iCloud** versions from Apple's website, not the Microsoft Store ones.
2. Plug your iPhone in with a cable and tap **Trust** on the phone.
3. Drag `EX700BRemote.ipa` into Sideloadly, enter your Apple ID, and press **Start**.
4. On the iPhone:
   - **Settings › General › VPN & Device Management**: tap your Apple ID and choose **Trust**.
   - **Settings › Privacy & Security › Developer Mode**: switch it on and restart. This option only appears after the first sideload.
5. Open **EX700B Remote**. When it asks to find devices on your local network, tap **Allow**.

With a free Apple ID the app stops opening after **7 days**. Plug in and press Start in Sideloadly again to renew it; your settings are kept. A paid Apple Developer account (£79 a year) would allow TestFlight instead, with no weekly refresh.

## 3. One-time TV settings

On the TV remote press **Menu**, then go to **Network › TV Remote App Settings**:

| Setting | Set to | Why |
|---|---|---|
| TV Remote | **On** | Lets the app send buttons |
| Powered On by Apps | **On** | Lets the app and Siri switch the TV on from standby |
| Wake on Wireless LAN / Networked Standby (if shown) | **On** | Keeps the TV reachable in standby |

With "Powered On by Apps" on, the standby light glows orange.

**Tip:** in your router, give the TV a fixed address (a "DHCP reservation"). The app copes if the address changes, but a fixed one is quicker.

## 4. Siri

These work once you've opened the app at least once. "Telly" is the app's Siri nickname; "EX700B Remote" works too.

| Say "Hey Siri, …" | Does |
|---|---|
| Turn on the telly / Telly on | Switches on, but only if it's off (the power button is a toggle) |
| Turn off the telly / Telly off | Switches to standby, but only if it's on |
| Turn the telly up / down | Volume ±5 |
| Mute the telly / Unmute the telly | Mute on or off |
| Pause the telly / Play the telly | Pause or play |
| YouTube on the telly | Opens YouTube, switching the TV on first if needed |
| **Aliens on the telly** / Telly aliens | 👽 The same: wakes the TV and opens YouTube |

### Just "Hey Siri, Aliens"

Apple insists that every built-in phrase includes the app's name. That's why the old version failed to build with a bare "Aliens". Your own shortcuts don't have that rule, so:

1. Open the **Shortcuts** app and tap **+**.
2. Search for **EX700B Remote** and add the **Aliens** action.
3. Rename the shortcut **Aliens** and tap Done.

Now "Hey Siri, Aliens" works. The same trick works for anything else, for example a shortcut called "BBC One" that uses **Press TV Button** with 1. You can also use **Open App on TV** with "Netflix", or **Set TV Volume** with 15.

## 5. Troubleshooting

| Problem | Fix |
|---|---|
| "iPhone needs your permission…" | Go to Settings › Privacy & Security › Local Network and switch on EX700B Remote. |
| "Can't reach the TV at …" | Check the TV is plugged in and "Powered On by Apps" is on, and that your phone is on the same Wi-Fi. Then use **Setup › Search Wi-Fi for the TV**. |
| "The TV refused the command" | Switch on TV › Menu › Network › TV Remote App Settings › **TV Remote**. |
| Shows "Standby" while the TV is on | Tap refresh. If it keeps happening, use **Lab › Power state and volume** and note what it says. |
| YouTube doesn't open | Look at **Apps** for the TV's own YouTube entry. **Lab › App list** shows the exact ID. |
| Siri says the app isn't set up | Open the app once after each install. Siri can take a minute to learn the phrases. |

## How it talks to the TV

Panasonic VIERA TVs from 2017 accept UPnP/SOAP commands on port **55000** without pairing:

- Buttons: `POST /nrc/control_0` running `X_SendKey` with an `NRC_…-ONOFF` key code
- Apps: `X_GetAppList` and `X_LaunchApp`
- Volume and mute: `POST /dmr/control_0` running `GetVolume`, `SetVolume`, `GetMute` and `SetMute`
- On or off: the TV counts as "on" when it answers a volume query (the same test Home Assistant uses)
- Finding the TV: the app asks every address on your Wi-Fi for `/nrc/ddd.xml`. Proper SSDP discovery would need a special multicast permission from Apple.

The TV's web server is fussy, so each request is sent as one compact line of XML with no spaces around the values.

## Project layout

```
EX700BRemote/
  EX700BRemoteApp.swift, ContentView.swift, AppModel.swift   app, tabs, shared state
  Models/        PanasonicTV (address, name), TVCommand (all key codes)
  Networking/    SOAPClient, PanasonicController, XML parsing, errors
  Discovery/     finds the TV on the Wi-Fi subnet
  Storage/       TVStore (remembers the TV; Siri reads it too)
  Views/         Remote, Apps, Setup, Lab screens
  Siri/          App Intents and Siri phrases
  Info.plist     bundle info, local-network permission, "Telly" nickname
  Assets.xcassets  app icon and accent colour
codemagic.yaml   cloud build that produces EX700BRemote.ipa
```

**Adding a new Swift file?** It must also be listed in `EX700BRemote.xcodeproj/project.pbxproj`. The Codemagic build checks this first and tells you if one is missing.
